extends RefCounted
class_name GameAbilityActivationRequest

# ======== PRIVATE VAR ======
var _ability_id: StringName = &""
var _grant_handle_id: int = 0
var _requester_handle: GameObjectHandle = null
var _owner_handle: GameObjectHandle = null
var _target_handles: Array[GameObjectHandle] = []
var _target_point: Vector3 = Vector3.ZERO
var _target_direction: Vector3 = Vector3.ZERO
var _execution_context: GameExecutionContext = null
var _activation_payload: Dictionary = {}

# ======= OVERRIDE =======
func _init(
	ability_id: StringName = &"",
	owner_handle: GameObjectHandle = null,
	execution_context: GameExecutionContext = null,
	requester_handle: GameObjectHandle = null
) -> void:
	_ability_id = ability_id
	_owner_handle = owner_handle
	_execution_context = execution_context
	_requester_handle = requester_handle

# ====== PUBLIC ========
func set_grant_handle_id(value: int) -> void: _grant_handle_id = value
func set_targets(value: Array[GameObjectHandle]) -> void: _target_handles = value.duplicate()
func set_target_point(value: Vector3) -> void: _target_point = value
func set_target_direction(value: Vector3) -> void: _target_direction = value
func set_activation_payload(value: Dictionary) -> void: _activation_payload = value.duplicate(true)
func get_ability_id() -> StringName: return _ability_id
func get_grant_handle_id() -> int: return _grant_handle_id
func get_requester_handle() -> GameObjectHandle: return _requester_handle
func get_owner_handle() -> GameObjectHandle: return _owner_handle
func get_target_handles() -> Array[GameObjectHandle]: return _target_handles.duplicate()
func get_target_point() -> Vector3: return _target_point
func get_target_direction() -> Vector3: return _target_direction
func get_execution_context() -> GameExecutionContext: return _execution_context
func get_activation_payload() -> Dictionary: return _activation_payload.duplicate(true)
