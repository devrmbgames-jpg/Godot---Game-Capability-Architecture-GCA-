extends Area3D
class_name GameMineExample

signal mine_triggered(instigator: GameObjectHandle, affected_count: int)
signal mine_armed_changed(armed: bool)

# ======== EXPORT =========
@export var kernel: GameObjectKernel = null
@export var targeting_service: GameTargetingService = null
@export var visual_mesh: MeshInstance3D = null
@export_range(0.1, 25.0, 0.1) var trigger_radius: float = 3.0
@export_range(0.0, 10000.0, 1.0) var damage_amount: float = 50.0
@export var auto_trigger_on_body_entered: bool = true

# ======== PRIVATE VAR ======
var _armed: bool = true

# ======= OVERRIDE =======
func _ready() -> void:
	var body_callable: Callable = Callable(self, "_on_body_entered")
	if not body_entered.is_connected(body_callable):
		body_entered.connect(body_callable)
	_update_visual_state()

# ====== HELPERS ========
func _update_visual_state() -> void:
	if visual_mesh == null:
		return
	visual_mesh.scale = Vector3.ONE if _armed else Vector3(1.0, 0.25, 1.0)

func _apply_radial_damage(instigator: GameObjectHandle, execution_context: GameExecutionContext) -> int:
	if targeting_service == null or kernel == null:
		return 0
	var owner_context: GameObjectContext = kernel.get_object_context()
	if owner_context == null:
		return 0
	var owner_handle: GameObjectHandle = owner_context.get_object_handle()
	var required_tags: Array[StringName] = []
	var excluded_ids: Array[StringName] = [owner_handle.get_stable_id()]
	var query: Dictionary = targeting_service.query_sphere(
		global_position,
		trigger_radius,
		GameCapabilityIds.DAMAGE_RECEIVER,
		required_tags,
		excluded_ids
	)
	var affected_count: int = 0
	for target_handle_value: Variant in query.get("handles", []):
		var target_handle: GameObjectHandle = target_handle_value as GameObjectHandle
		if target_handle == null or not target_handle.is_resolved():
			continue
		var target_context: GameObjectContext = target_handle.get_context()
		if target_context == null:
			continue
		var receiver: GameDamageReceiver = target_context.get_capability(GameCapabilityIds.DAMAGE_RECEIVER) as GameDamageReceiver
		if receiver == null:
			continue
		var damage_tags: Array[StringName] = [&"damage.explosion", &"damage.example.mine"]
		var request := GameDamageRequest.new(
			owner_handle,
			instigator if instigator != null else owner_handle,
			target_handle,
			damage_amount,
			damage_tags,
			execution_context
		)
		if receiver.apply_damage(request).is_success():
			affected_count += 1
	return affected_count

# ====== PUBLIC ========
func is_armed() -> bool:
	return _armed

func arm() -> GameCommandResult:
	if _armed:
		return GameCommandResult.success_unchanged(&"mine_already_armed")
	_armed = true
	_update_visual_state()
	mine_armed_changed.emit(true)
	return GameCommandResult.success_changed(&"mine_armed")

func disarm() -> GameCommandResult:
	if not _armed:
		return GameCommandResult.success_unchanged(&"mine_already_disarmed")
	_armed = false
	_update_visual_state()
	mine_armed_changed.emit(false)
	return GameCommandResult.success_changed(&"mine_disarmed")

func trigger(instigator: GameObjectHandle = null) -> GameCommandResult:
	if not _armed:
		return GameCommandResult.rejected_temporary(&"mine_not_armed", "The example mine is not armed.")
	_armed = false
	_update_visual_state()
	var execution_context: GameExecutionContext = null
	if kernel != null and kernel.get_object_context() != null:
		execution_context = kernel.get_object_context().create_root_execution_context(&"example.mine.triggered", "Example mine triggered")
	if execution_context == null:
		execution_context = GameExecutionContext.new()
	var affected_count: int = _apply_radial_damage(instigator, execution_context)
	mine_armed_changed.emit(false)
	mine_triggered.emit(instigator, affected_count)
	return GameCommandResult.success_changed(&"mine_triggered", {"affected_count": affected_count})

# ===== SLOTS =======
func _on_body_entered(_body: Node3D) -> void:
	if auto_trigger_on_body_entered:
		trigger()
