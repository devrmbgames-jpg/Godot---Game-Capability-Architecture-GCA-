@tool
extends GameControlSource
## Control source that converts Godot Input actions into normalized intents.
##
## Reads configured input actions only when it owns the matching channels and
## delegates all gameplay execution to [GameControlEndpoint]. Interaction buttons are
## normal ability-slot bindings; this source does not own target-specific interaction logic.
class_name GamePlayerInputSource

# ======== EXPORT =========
@export var movement_left_action: StringName = &"move_left"
@export var movement_right_action: StringName = &"move_right"
@export var movement_forward_action: StringName = &"move_forward"
@export var movement_back_action: StringName = &"move_back"
@export var ability_input_bindings: Array[GameAbilityInputBinding] = []
@export var input_enabled: bool = true

# ======== PRIVATE VAR ======
var _execution_context_factory: Callable = Callable()

# ======= OVERRIDE =======
## Assigns default source identity and requested gameplay channels.
func _init() -> void:
	if source_id.is_empty():
		source_id = &"control.player"
	if requested_channels.is_empty():
		requested_channels = [
			GameControlChannels.MOVEMENT,
			GameControlChannels.ABILITIES,
		]

## Returns warnings for incomplete ability action-to-slot mappings.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = super()
	for binding: GameAbilityInputBinding in ability_input_bindings:
		if binding == null or not binding.is_valid():
			warnings.append(
				"GamePlayerInputSource contains an invalid ability input binding."
			)
	return warnings

## Samples input during physics updates and submits normalized owned-channel intents.
func _physics_process(_delta: float) -> void:
	if not input_enabled or is_suspended() or not _execution_context_factory.is_valid():
		return

	var context: GameExecutionContext = _execution_context_factory.call(
		&"control.player_input",
		"Player input"
	) as GameExecutionContext
	var input_vector: Vector2 = Input.get_vector(
		movement_left_action,
		movement_right_action,
		movement_forward_action,
		movement_back_action
	)
	
	var move_direction: Vector3 = Vector3(input_vector.x, 0.0, input_vector.y)
	
	var camera := get_viewport().get_camera_3d()
	if camera :
		var camera_forward: Vector3 = -camera.global_basis.z
		var camera_right: Vector3 = camera.global_basis.x
		camera_forward.y = 0.0
		camera_right.y = 0.0
		camera_forward = camera_forward.normalized()
		camera_right = camera_right.normalized()
		
		move_direction = (
			camera_right * input_vector.x
			+ camera_forward * -input_vector.y
		)

	if owns_channel(GameControlChannels.MOVEMENT):
		submit_intent(
			&"movement.desired",
			GameControlChannels.MOVEMENT,
			context,
			{
				&"direction": move_direction,
				&"magnitude": minf(move_direction.length(), 1.0),
			},
			true
		)

	if owns_channel(GameControlChannels.ABILITIES):
		for binding: GameAbilityInputBinding in ability_input_bindings:
			if binding == null or not binding.is_valid():
				continue
			if not Input.is_action_just_pressed(binding.input_action):
				continue
			submit_intent(
				&"ability.activate",
				GameControlChannels.ABILITIES,
				context,
				{&"slot_id": binding.slot_id}
			)

# ====== PUBLIC ========
## Sets the callable used to create root execution contexts for input intents.
func set_execution_context_factory(factory: Callable) -> void:
	_execution_context_factory = factory
