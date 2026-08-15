extends CharacterBody3D
class_name GameEnemyExample

signal enemy_target_changed(target: Node3D)

# ======== EXPORT =========
@export var kernel: GameObjectKernel = null
@export var control_arbiter: GameControlArbiter = null
@export var control_endpoint: GameControlEndpoint = null
@export var ai_control_source: GameMockAIControlSource = null
@export var abilities: GameAbilities = null
@export var effects: GameEffects = null
@export var target_node: Node3D = null
@export_range(0.1, 50.0, 0.1) var chase_distance: float = 12.0
@export_range(0.0, 10.0, 0.1) var stop_distance: float = 1.8

# ======== PRIVATE VAR ======
var _control_attached: bool = false

# ======= OVERRIDE =======
func _ready() -> void:
	_attach_ai_control()

func _physics_process(delta: float) -> void:
	_tick_ai()
	if abilities != null:
		abilities.advance_time(delta)
	if effects != null and kernel != null and kernel.get_object_context() != null:
		var context: GameExecutionContext = kernel.get_object_context().create_root_execution_context(&"example.enemy.tick", "Example enemy scheduler")
		effects.advance_time(delta, context)
	if kernel != null:
		kernel.process_execution_queue()

# ====== HELPERS ========
func _attach_ai_control() -> void:
	if _control_attached or kernel == null or control_arbiter == null or control_endpoint == null or ai_control_source == null:
		return
	if kernel.get_object_context() == null:
		return
	if ai_control_source.attach(control_endpoint, control_arbiter).is_success():
		ai_control_source.request_control()
		_control_attached = true

func _tick_ai() -> void:
	if not _control_attached or target_node == null or kernel == null or kernel.get_object_context() == null:
		return
	var offset: Vector3 = target_node.global_position - global_position
	offset.y = 0.0
	var context: GameExecutionContext = kernel.get_object_context().create_root_execution_context(&"example.enemy.control", "Example enemy chase")
	if offset.length() > chase_distance or offset.length() <= stop_distance:
		ai_control_source.stop(context)
	else:
		ai_control_source.move(offset.normalized(), 1.0, context)

# ====== PUBLIC ========
func set_target(value: Node3D) -> void:
	target_node = value
	enemy_target_changed.emit(target_node)

func has_ai_control() -> bool:
	return _control_attached
