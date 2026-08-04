@tool
extends GameFeature
class_name GameMovementMotor

signal movement_request_applied(request: GameMovementRequest)
signal movement_stopped(reason: StringName)

# ======== PRIVATE VAR ======
var _enabled: bool = true
var _active_constraints: Dictionary = {}
var _constraint_counter: int = 0

# ======= OVERRIDE =======
func _init() -> void:
	feature_id = &"object.movement_motor"
	if provided_capabilities.is_empty():
		for capability_id: StringName in [GameCapabilityIds.MOVEMENT_MOTOR, GameCapabilityIds.MOVEMENT_QUERY]:
			var spec := GameCapabilitySpec.new()
			spec.capability_id = capability_id
			provided_capabilities.append(spec)

# ====== PUBLIC ========
func apply_movement_request(request: GameMovementRequest) -> GameCommandResult:
	if not _enabled: return GameCommandResult.rejected_temporary(&"movement_disabled", "Movement motor is disabled.")
	if request == null or request.get_execution_context() == null: return GameCommandResult.configuration_error(&"invalid_movement_request", "Movement request is incomplete.")
	var result: GameCommandResult = on_apply_movement_request(request)
	if result.is_success(): movement_request_applied.emit(request)
	return result

func on_apply_movement_request(_request: GameMovementRequest) -> GameCommandResult:
	return GameCommandResult.success_unchanged(&"movement_request_accepted")

func set_enabled(value: bool, reason: StringName = &"state_changed") -> void:
	_enabled = value
	if not _enabled: movement_stopped.emit(reason)

func is_enabled() -> bool: return _enabled

func add_constraint(constraint_id: StringName, payload: Dictionary = {}) -> int:
	_constraint_counter += 1
	_active_constraints[_constraint_counter] = {"constraint_id": constraint_id, "payload": payload.duplicate(true)}
	return _constraint_counter

func remove_constraint(handle_id: int) -> bool:
	return _active_constraints.erase(handle_id)

func has_constraint(constraint_id: StringName) -> bool:
	for record: Dictionary in _active_constraints.values():
		if record.get("constraint_id", &"") == constraint_id: return true
	return false

func get_debug_snapshot() -> Dictionary:
	return {"enabled": _enabled, "constraints": _active_constraints.duplicate(true)}
