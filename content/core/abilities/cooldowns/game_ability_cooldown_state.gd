extends RefCounted
class_name GameAbilityCooldownState

# ======== PRIVATE VAR ======
var _key: StringName = &""
var _remaining: float = 0.0
var _source_grant_handle_id: int = 0

# ======= OVERRIDE =======
func _init(key: StringName, duration: float, source_grant_handle_id: int = 0) -> void:
	_key = key
	_remaining = maxf(0.0, duration)
	_source_grant_handle_id = source_grant_handle_id

# ====== PUBLIC ========
func advance(delta: float) -> void: _remaining = maxf(0.0, _remaining - maxf(delta, 0.0))
func refresh(duration: float) -> void: _remaining = maxf(_remaining, duration)
func is_active() -> bool: return _remaining > 0.0
func get_key() -> StringName: return _key
func get_remaining() -> float: return _remaining
func get_source_grant_handle_id() -> int: return _source_grant_handle_id
func to_dictionary() -> Dictionary: return {"key": _key, "remaining": _remaining, "source_grant_handle_id": _source_grant_handle_id}
