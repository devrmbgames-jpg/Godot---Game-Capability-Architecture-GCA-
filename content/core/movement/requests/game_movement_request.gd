extends RefCounted
## Normalized command data for a movement motor.
##
## Carries movement type, direction, magnitude, target point, tolerance, custom
## payload, and the execution context that requested the movement.
class_name GameMovementRequest

# ======= ENUMS =========
enum Type {
	SET_DESIRED_MOVEMENT,
	STOP,
	FACE_DIRECTION,
	MOVE_TO_POINT,
	IMPULSE,
	SET_MODE,
}

# ======== PRIVATE VAR ======
var _type: int = Type.STOP
var _direction: Vector3 = Vector3.ZERO
var _magnitude: float = 0.0
var _target_point: Vector3 = Vector3.ZERO
var _tolerance: float = 0.1
var _payload: Dictionary = {}
var _execution_context: GameExecutionContext = null

# ======= OVERRIDE =======
## Creates a movement request of [param type] with its causal context.
func _init(type: int = Type.STOP, execution_context: GameExecutionContext = null) -> void:
	_type = type
	_execution_context = execution_context

# ====== PUBLIC ========
## Sets the desired world-space direction.
func set_direction(value: Vector3) -> void: _direction = value
## Sets normalized movement magnitude in the range [code]0.0..1.0[/code].
func set_magnitude(value: float) -> void: _magnitude = clampf(value, 0.0, 1.0)
## Sets the world-space move target.
func set_target_point(value: Vector3) -> void: _target_point = value
## Sets a non-negative arrival tolerance.
func set_tolerance(value: float) -> void: _tolerance = maxf(value, 0.0)
## Stores a deep copy of additional motor-specific request data.
func set_payload(value: Dictionary) -> void: _payload = value.duplicate(true)
## Returns the movement request type.
func get_type() -> int: return _type
## Returns the configured direction.
func get_direction() -> Vector3: return _direction
## Returns normalized movement magnitude.
func get_magnitude() -> float: return _magnitude
## Returns the configured target point.
func get_target_point() -> Vector3: return _target_point
## Returns arrival tolerance.
func get_tolerance() -> float: return _tolerance
## Returns a deep copy of custom request data.
func get_payload() -> Dictionary: return _payload.duplicate(true)
## Returns the causal execution context.
func get_execution_context() -> GameExecutionContext: return _execution_context
