extends RefCounted
class_name GameInteractionReservation

# ======== PRIVATE VAR ======
var _handle_id: int = 0
var _source_handle: GameObjectHandle = null
var _target_handle: GameObjectHandle = null
var _offer_id: StringName = &""
var _priority: int = 0
var _expires_at: float = 0.0
var _root_operation_id: int = 0
var _active: bool = true

# ======= OVERRIDE =======
func _init(handle_id: int = 0, source_handle: GameObjectHandle = null, target_handle: GameObjectHandle = null, offer_id: StringName = &"", priority: int = 0, expires_at: float = 0.0, root_operation_id: int = 0) -> void:
	_handle_id = handle_id
	_source_handle = source_handle
	_target_handle = target_handle
	_offer_id = offer_id
	_priority = priority
	_expires_at = expires_at
	_root_operation_id = root_operation_id

# ====== PUBLIC ========
func release() -> void: _active = false
func is_active() -> bool: return _active
func is_expired(simulation_time: float) -> bool: return _expires_at > 0.0 and simulation_time >= _expires_at
func get_handle_id() -> int: return _handle_id
func get_source_handle() -> GameObjectHandle: return _source_handle
func get_target_handle() -> GameObjectHandle: return _target_handle
func get_offer_id() -> StringName: return _offer_id
func get_priority() -> int: return _priority
func get_root_operation_id() -> int: return _root_operation_id
func to_dictionary() -> Dictionary:
	return {"handle_id": _handle_id, "offer_id": _offer_id, "priority": _priority, "expires_at": _expires_at, "root_operation_id": _root_operation_id, "active": _active}
