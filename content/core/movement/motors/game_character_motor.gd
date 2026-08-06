@tool
extends GameMovementMotor
## CharacterBody3D adapter for normalized GCA movement requests.
##
## Owns low-level velocity, gravity, facing, and move-to behavior while reading an
## optional movement-speed attribute. It never reads input or activates abilities.
class_name GameCharacterMotor

# ======== EXPORT =========
@export var speed_attribute_id: StringName = &"movement_speed"
@export var fallback_speed: float = 5.0
@export var gravity_acceleration: float = 24.0
@export var turn_speed: float = 12.0

# ======== PRIVATE VAR ======
var _body: CharacterBody3D = null
var _attributes: GameAttributes = null
var _desired_direction: Vector3 = Vector3.ZERO
var _desired_magnitude: float = 0.0
var _move_target: Vector3 = Vector3.ZERO
var _move_tolerance: float = 0.1
var _has_move_target: bool = false

# ======= OVERRIDE =======
## Configures the concrete motor feature and optional attribute dependency.
func _init() -> void:
	super()
	feature_id = &"object.character_motor"
	if optional_dependencies.is_empty():
		var dependency := GameCapabilityDependency.new()
		dependency.capability_id = GameCapabilityIds.ATTRIBUTES_QUERY
		dependency.required = false
		optional_dependencies.append(dependency)

## Validates a CharacterBody3D object root and enables physics processing.
func on_game_initialize() -> GameCommandResult:
	var root: Node = get_context().get_object_root()
	if not root is CharacterBody3D: return GameCommandResult.configuration_error(&"invalid_character_motor_root", "GameCharacterMotor requires CharacterBody3D object root.")
	_body = root as CharacterBody3D
	_attributes = get_dependency(GameCapabilityIds.ATTRIBUTES_QUERY) as GameAttributes
	set_physics_process(true)
	return GameCommandResult.success_changed(&"character_motor_initialized")

## Clears movement ownership and velocity when gameplay deactivates.
func on_game_deactivate(reason: StringName) -> void:
	_desired_direction = Vector3.ZERO; _desired_magnitude = 0.0; _has_move_target = false
	if _body != null: _body.velocity = Vector3.ZERO
	movement_stopped.emit(reason)

## Disables physics processing and releases runtime dependencies.
func on_game_shutdown() -> void:
	set_physics_process(false)
	_body = null; _attributes = null

## Applies desired movement, gravity, facing, and CharacterBody3D motion each physics frame.
func _physics_process(delta: float) -> void:
	if _body == null or not is_enabled(): return
	if _has_move_target:
		var offset: Vector3 = _move_target - _body.global_position
		offset.y = 0.0
		if offset.length() <= _move_tolerance:
			_has_move_target = false; _desired_direction = Vector3.ZERO; _desired_magnitude = 0.0
		else:
			_desired_direction = offset.normalized(); _desired_magnitude = 1.0
	var speed: float = _attributes.get_value(speed_attribute_id, fallback_speed) if _attributes != null else fallback_speed
	var horizontal: Vector3 = _desired_direction.normalized() * speed * _desired_magnitude
	_body.velocity.x = horizontal.x; _body.velocity.z = horizontal.z
	if not _body.is_on_floor(): _body.velocity.y -= gravity_acceleration * delta
	else: _body.velocity.y = minf(_body.velocity.y, 0.0)
	if horizontal.length_squared() > 0.0001:
		var target_yaw: float = atan2(-horizontal.x, -horizontal.z)
		_body.rotation.y = lerp_angle(_body.rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))
	_body.move_and_slide()

## Applies supported desired-movement, stop, move-to, and impulse requests.
func on_apply_movement_request(request: GameMovementRequest) -> GameCommandResult:
	match request.get_type():
		GameMovementRequest.Type.SET_DESIRED_MOVEMENT:
			_desired_direction = request.get_direction(); _desired_direction.y = 0.0
			_desired_magnitude = request.get_magnitude(); _has_move_target = false
		GameMovementRequest.Type.STOP:
			_desired_direction = Vector3.ZERO; _desired_magnitude = 0.0; _has_move_target = false
		GameMovementRequest.Type.MOVE_TO_POINT:
			_move_target = request.get_target_point(); _move_tolerance = request.get_tolerance(); _has_move_target = true
		GameMovementRequest.Type.IMPULSE:
			if _body != null: _body.velocity += request.get_direction() * request.get_magnitude()
		_:
			return GameCommandResult.rejected_permanent(&"unsupported_movement_request", "Character motor does not support this request type.")
	return GameCommandResult.success_changed(&"movement_request_applied")

## Extends base motor diagnostics with velocity and move-target state.
func get_debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = super()
	snapshot["velocity"] = _body.velocity if _body != null else Vector3.ZERO
	snapshot["desired_direction"] = _desired_direction
	snapshot["desired_magnitude"] = _desired_magnitude
	snapshot["has_move_target"] = _has_move_target
	return snapshot
