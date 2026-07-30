extends RefCounted
class_name GameQuery

# ======== PRIVATE VAR ======
var _query_type_id: StringName = &""
var _requester_handle: GameObjectHandle = null
var _target_handle: GameObjectHandle = null
var _required_capability_id: StringName = &""
var _payload: Variant = null

# ======= OVERRIDE =======
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
func get_query_type_id() -> StringName:
    return _query_type_id

func get_requester_handle() -> GameObjectHandle:
    return _requester_handle

func get_target_handle() -> GameObjectHandle:
    return _target_handle

func get_required_capability_id() -> StringName:
    return _required_capability_id

func get_payload() -> Variant:
    return _payload
