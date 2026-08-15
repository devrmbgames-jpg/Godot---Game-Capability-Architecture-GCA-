extends CharacterBody3D
class_name GameGOAPSurvivalExample

signal goap_action_changed(action_name: StringName)
signal goap_sequence_completed(final_state: Dictionary)

# ======== EXPORT =========
@export var kernel: GameObjectKernel = null
@export var goap_agent: GoapAgent = null
@export var goap_adapter: GameGOAPAdapter = null
@export var control_source: GameMockAIControlSource = null
@export var food_visual: MeshInstance3D = null
@export var cooked_visual: MeshInstance3D = null
@export var bed_visual: MeshInstance3D = null

# ======== PRIVATE VAR ======
var _sequence_completed: bool = false

# ======= OVERRIDE =======
func _ready() -> void:
	if goap_agent == null:
		return
	goap_agent.init(self)
	var world_state: GoapWorldState = goap_agent.get_world_state()
	world_state.set_state("food_found", false)
	world_state.set_state("has_food", false)
	world_state.set_state("food_cooked", false)
	world_state.set_state("hungry", true)
	world_state.set_state("tired", true)
	if goap_adapter != null:
		goap_adapter.object_kernel = kernel
		goap_adapter.goap_world_state = world_state
		goap_adapter.control_source = control_source
	var action_callable: Callable = Callable(self, "_on_action_changed")
	if not goap_agent.action_changed.is_connected(action_callable):
		goap_agent.action_changed.connect(action_callable)
	_update_visuals(world_state)

func _process(delta: float) -> void:
	if goap_agent == null or _sequence_completed:
		return
	goap_agent.process(delta)
	var world_state: GoapWorldState = goap_agent.get_world_state()
	_update_visuals(world_state)
	if not bool(world_state.get_state("hungry", true)) and not bool(world_state.get_state("tired", true)):
		_sequence_completed = true
		goap_sequence_completed.emit(world_state._state.duplicate(true))

# ====== HELPERS ========
func _update_visuals(world_state: GoapWorldState) -> void:
	if food_visual != null:
		food_visual.visible = bool(world_state.get_state("food_found", false)) and not bool(world_state.get_state("has_food", false))
	if cooked_visual != null:
		cooked_visual.visible = bool(world_state.get_state("food_cooked", false))
	if bed_visual != null:
		bed_visual.scale = Vector3.ONE * (1.15 if not bool(world_state.get_state("tired", true)) else 1.0)

# ====== PUBLIC ========
func is_sequence_completed() -> bool:
	return _sequence_completed

func get_world_state_snapshot() -> Dictionary:
	if goap_agent == null or goap_agent.get_world_state() == null:
		return {}
	return goap_agent.get_world_state()._state.duplicate(true)

# ===== SLOTS =======
func _on_action_changed(action: GoapAction) -> void:
	var action_name: StringName = StringName(action.name) if action != null else &""
	goap_action_changed.emit(action_name)
