extends RefCounted
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
func _init(type: int = Type.STOP, execution_context: GameExecutionContext = null) -> void:
	_type = type
	_execution_context = execution_context

# ====== PUBLIC ========
func set_direction(value: Vector3) -> void: _direction = value
func set_magnitude(value: float) -> void: _magnitude = clampf(value, 0.0, 1.0)
func set_target_point(value: Vector3) -> void: _target_point = value
func set_tolerance(value: float) -> void: _tolerance = maxf(value, 0.0)
func set_payload(value: Dictionary) -> void: _payload = value.duplicate(true)
func get_type() -> int: return _type
func get_direction() -> Vector3: return _direction
func get_magnitude() -> float: return _magnitude
func get_target_point() -> Vector3: return _target_point
func get_tolerance() -> float: return _tolerance
func get_payload() -> Dictionary: return _payload.duplicate(true)
func get_execution_context() -> GameExecutionContext: return _execution_context
