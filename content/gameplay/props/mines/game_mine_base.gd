extends Area3D
class_name GameMineBase

# ======= ON READY ========
@onready var _kernel: GameObjectKernel = $GameObjectKernel

# ======== EXPORT =========
@export_range(0.0, 10000.0, 0.1) var damage: float = 50.0
@export var damage_tags: Array[StringName] = [&"damage.explosive"]

# ======== PRIVATE VAR ======
var _triggered: bool = false

# ======= OVERRIDE =======
func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

# ====== HELPERS ========
func _find_kernel(root: Node) -> GameObjectKernel:
	for child: Node in root.get_children():
		if child is GameObjectKernel:
			return child as GameObjectKernel
	return null

# ===== SLOTS =======
func _on_body_entered(body: Node3D) -> void:
	if _triggered or _kernel == null:
		return
	var target_kernel: GameObjectKernel = _find_kernel(body)
	if target_kernel == null:
		return
	var source_context: GameObjectContext = _kernel.get_object_context()
	var target_context: GameObjectContext = target_kernel.get_object_context()
	if source_context == null or target_context == null:
		return
	var receiver: GameDamageReceiver = target_context.get_capability(
		GameCapabilityIds.DAMAGE_RECEIVER
	) as GameDamageReceiver
	if receiver == null:
		return
	var source_handle: GameObjectHandle = source_context.get_object_handle()
	var target_handle: GameObjectHandle = target_context.get_object_handle()
	var execution_context: GameExecutionContext = _kernel.create_root_execution_context(
		&"mine.trigger",
		"Mine triggered"
	)
	var request := GameDamageRequest.new(
		source_handle,
		source_handle,
		target_handle,
		damage,
		damage_tags,
		execution_context
	)
	var result: GameCommandResult = receiver.apply_damage(request)
	if not result.is_success():
		return
	_triggered = true
	var despawn_service: GameSpawnService = source_context.get_world_port(
		GameWorldPortIds.DESPAWN_REQUEST
	) as GameSpawnService
	if despawn_service != null:
		despawn_service.despawn(source_handle, &"mine_triggered", true)
	else:
		queue_free()
