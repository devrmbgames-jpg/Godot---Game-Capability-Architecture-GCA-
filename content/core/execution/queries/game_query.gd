extends RefCounted
## Immutable side-effect-free request for reading gameplay state from a target kernel.
class_name GameQuery

# ======== PRIVATE VAR ======
var _query_type_id: StringName = &""
var _requester_handle: GameObjectHandle = null
var _target_handle: GameObjectHandle = null
var _required_capability_id: StringName = &""
var _payload: Variant = null

# ======= OVERRIDE =======
## Creates an addressed gameplay query with an optional routing capability and payload.
func _init(
	query_type_id: StringName = &"",
	requester_handle: GameObjectHandle = null,
	target_handle: GameObjectHandle = null,
	required_capability_id: StringName = &"",
	payload: Variant = null
) -> void:
	_query_type_id = query_type_id
	_requester_handle = requester_handle
	_target_handle = target_handle
	_required_capability_id = required_capability_id
	_payload = payload

# ====== PUBLIC ========
## Returns the stable query type identifier.
func get_query_type_id() -> StringName:
	return _query_type_id

## Returns the handle of the query requester.
func get_requester_handle() -> GameObjectHandle:
	return _requester_handle

## Returns the explicit query target handle.
func get_target_handle() -> GameObjectHandle:
	return _target_handle

## Returns the capability used to restrict candidate handlers, or an empty ID.
func get_required_capability_id() -> StringName:
	return _required_capability_id

## Returns the query payload without transforming it.
func get_payload() -> Variant:
	return _payload
