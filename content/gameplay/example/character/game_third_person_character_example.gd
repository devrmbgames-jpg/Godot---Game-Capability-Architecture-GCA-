extends CharacterBody3D
class_name GameThirdPersonCharacterExample

signal control_ready()

# ======== EXPORT =========
@export var kernel: GameObjectKernel = null
@export var control_arbiter: GameControlArbiter = null
@export var control_endpoint: GameControlEndpoint = null
@export var player_input_source: GamePlayerInputSource = null
@export var abilities: GameAbilities = null
@export var effects: GameEffects = null

# ======== PRIVATE VAR ======
var _control_attached: bool = false

# ======= OVERRIDE =======
func _ready() -> void:
	_ensure_example_input_actions()
	_attach_player_control()

func _physics_process(delta: float) -> void:
	if abilities != null:
		abilities.advance_time(delta)
	if effects != null and kernel != null and kernel.get_object_context() != null:
		var context: GameExecutionContext = kernel.get_object_context().create_root_execution_context(&"example.character.tick", "Example character scheduler")
		effects.advance_time(delta, context)
	if kernel != null:
		kernel.process_execution_queue()

# ====== HELPERS ========
func _ensure_input_action(action_id: StringName, physical_keycode: int) -> void:
	if InputMap.has_action(action_id):
		return
	InputMap.add_action(action_id)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_id, key_event)

func _ensure_example_input_actions() -> void:
	if player_input_source == null:
		return
	_ensure_input_action(player_input_source.movement_left_action, KEY_A)
	_ensure_input_action(player_input_source.movement_right_action, KEY_D)
	_ensure_input_action(player_input_source.movement_forward_action, KEY_W)
	_ensure_input_action(player_input_source.movement_back_action, KEY_S)
	_ensure_input_action(player_input_source.interaction_action, KEY_E)
	_ensure_input_action(&"ability_primary", KEY_SPACE)

func _attach_player_control() -> void:
	if _control_attached or kernel == null or control_arbiter == null or control_endpoint == null or player_input_source == null:
		return
	if kernel.get_object_context() == null:
		return
	player_input_source.set_execution_context_factory(func(cause: StringName, label: String) -> GameExecutionContext:
		return kernel.get_object_context().create_root_execution_context(cause, label)
	)
	var attach_result: GameCommandResult = player_input_source.attach(control_endpoint, control_arbiter)
	if not attach_result.is_success():
		return
	player_input_source.request_control()
	_control_attached = true
	control_ready.emit()

# ====== PUBLIC ========
func is_control_attached() -> bool:
	return _control_attached

func get_reference_dimensions() -> Vector3:
	return Vector3(1.0, 2.0, 1.0)
