extends Node3D
class_name GameDialogueRewardExample

signal dialogue_started()
signal reward_granted(result: Dictionary)

# ======= CONSTS =========
const REWARD_ABILITY: GameAbilityDefinition = preload("res://content/gameplay/example/shared/ability_speed_focus_example.tres")
const PLAYER_ID: StringName = &"example.character.player"

# ======== EXPORT =========
@export var player_kernel: GameObjectKernel = null
@export var npc_kernel: GameObjectKernel = null
@export var object_resolver: GameObjectResolver = null
@export var dialogue_adapter: GameDialogueAdapter = null
@export var dialogue_resource: Resource = null

# ======== PRIVATE VAR ======
var _reward_received: bool = false

# ======= OVERRIDE =======
func _ready() -> void:
	_register_participants()
	if dialogue_adapter != null:
		dialogue_adapter.ability_definitions[REWARD_ABILITY.ability_id] = REWARD_ABILITY

# ====== HELPERS ========
func _register_participants() -> void:
	if object_resolver == null:
		return
	for kernel: GameObjectKernel in [player_kernel, npc_kernel]:
		if kernel == null or kernel.get_object_context() == null:
			continue
		object_resolver.register_handle(kernel.get_object_context().get_object_handle())

# ====== PUBLIC ========
func start_dialogue() -> GameCommandResult:
	if dialogue_resource == null:
		return GameCommandResult.configuration_error(&"missing_dialogue_resource", "Dialogue resource is not assigned.")
	DialogueManager.show_dialogue_balloon(dialogue_resource, "start", [self])
	dialogue_started.emit()
	return GameCommandResult.success_changed(&"dialogue_started")

func can_receive_reward() -> bool:
	return not _reward_received

func grant_reward() -> bool:
	if _reward_received or dialogue_adapter == null:
		return false
	var result: Dictionary = dialogue_adapter.grant_ability(PLAYER_ID, REWARD_ABILITY.ability_id)
	_reward_received = bool(result.get("success", false)) or int(result.get("status", -1)) in [0, 1]
	reward_granted.emit(result)
	return _reward_received

func has_received_reward() -> bool:
	return _reward_received
