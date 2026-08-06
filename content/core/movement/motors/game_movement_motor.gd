@tool
extends GameFeature
## Abstract capability provider for low-level object movement.
##
## Validates normalized [GameMovementRequest] values, owns enable state and
## source-addressable constraints, and delegates concrete movement to
## [method on_apply_movement_request].
class_name GameMovementMotor

## Emitted after a movement request is accepted by the concrete motor.
signal movement_request_applied(request: GameMovementRequest)
## Emitted when the motor is disabled and movement must stop.
signal movement_stopped(reason: StringName)

# ======== PRIVATE VAR ======
var _enabled: bool = true
var _active_constraints: Dictionary = {}
var _constraint_counter: int = 0

# ======= OVERRIDE =======
## Configures movement command and query capabilities.
func _init() -> void:
	feature_id = &"object.movement_motor"
	if provided_capabilities.is_empty():
		for capability_id: StringName in [GameCapabilityIds.MOVEMENT_MOTOR, GameCapabilityIds.MOVEMENT_QUERY]:
			var spec := GameCapabilitySpec.new()
			spec.capability_id = capability_id
			provided_capabilities.append(spec)

# ====== PUBLIC ========
## Validates and forwards one request to the concrete motor implementation.
func apply_movement_request(request: GameMovementRequest) -> GameCommandResult:
	if not _enabled: return GameCommandResult.rejected_temporary(&"movement_disabled", "Movement motor is disabled.")
	if request == null or request.get_execution_context() == null: return GameCommandResult.configuration_error(&"invalid_movement_request", "Movement request is incomplete.")
	var result: GameCommandResult = on_apply_movement_request(request)
	if result.is_success(): movement_request_applied.emit(request)
	return result

## Virtual hook that applies a validated movement request.
func on_apply_movement_request(_request: GameMovementRequest) -> GameCommandResult:
	return GameCommandResult.success_unchanged(&"movement_request_accepted")

## Enables or disables the motor and emits a stop notification when disabled.
func set_enabled(value: bool, reason: StringName = &"state_changed") -> void:
	_enabled = value
	if not _enabled: movement_stopped.emit(reason)

## Returns whether the motor accepts movement requests.
func is_enabled() -> bool: return _enabled

## Adds a source-owned movement constraint and returns its runtime handle.
func add_constraint(constraint_id: StringName, payload: Dictionary = {}) -> int:
	_constraint_counter += 1
	_active_constraints[_constraint_counter] = {"constraint_id": constraint_id, "payload": payload.duplicate(true)}
	return _constraint_counter

## Removes one movement constraint by handle.
func remove_constraint(handle_id: int) -> bool:
	return _active_constraints.erase(handle_id)

## Returns whether any active constraint uses [param constraint_id].
func has_constraint(constraint_id: StringName) -> bool:
	for record: Dictionary in _active_constraints.values():
		if record.get("constraint_id", &"") == constraint_id: return true
	return false

## Returns motor enable state and a deep copy of active constraints.
func get_debug_snapshot() -> Dictionary:
	return {"enabled": _enabled, "constraints": _active_constraints.duplicate(true)}
