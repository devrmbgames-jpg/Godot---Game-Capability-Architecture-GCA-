extends RefCounted
## Normalized request to activate an ability for one owner.
##
## Identifies an ability or explicit grant and carries requester, owner, targets,
## directional data, execution context, and custom activation payload.
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
## Creates a request with the minimum owner and causal context data.
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
## Selects a specific grant handle instead of using grant-selection policy.
func set_grant_handle_id(value: int) -> void: _grant_handle_id = value
## Replaces target handles with a shallow copy of [param value].
func set_targets(value: Array[GameObjectHandle]) -> void: _target_handles = value.duplicate()
## Sets the normalized world-space target point.
func set_target_point(value: Vector3) -> void: _target_point = value
## Sets the normalized target direction.
func set_target_direction(value: Vector3) -> void: _target_direction = value
## Stores a deep copy of custom activation data.
func set_activation_payload(value: Dictionary) -> void: _activation_payload = value.duplicate(true)
## Returns the requested ability definition ID.
func get_ability_id() -> StringName: return _ability_id
## Returns the explicit grant handle, or [code]0[/code] when policy should select it.
func get_grant_handle_id() -> int: return _grant_handle_id
## Returns the object or system that requested activation.
func get_requester_handle() -> GameObjectHandle: return _requester_handle
## Returns the ability owner.
func get_owner_handle() -> GameObjectHandle: return _owner_handle
## Returns a copy of explicit target handles.
func get_target_handles() -> Array[GameObjectHandle]: return _target_handles.duplicate()
## Returns the normalized target point.
func get_target_point() -> Vector3: return _target_point
## Returns the normalized target direction.
func get_target_direction() -> Vector3: return _target_direction
## Returns the causal execution context.
func get_execution_context() -> GameExecutionContext: return _execution_context
## Returns a deep copy of custom activation data.
func get_activation_payload() -> Dictionary: return _activation_payload.duplicate(true)
