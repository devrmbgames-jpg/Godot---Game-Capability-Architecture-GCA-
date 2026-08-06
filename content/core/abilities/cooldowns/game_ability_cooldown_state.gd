extends RefCounted
## Lightweight runtime state for one ability cooldown key.
##
## Tracks remaining simulation time and the grant that started the cooldown.
class_name GameAbilityCooldownState

# ======== PRIVATE VAR ======
var _key: StringName = &""
var _remaining: float = 0.0
var _source_grant_handle_id: int = 0

# ======= OVERRIDE =======
## Creates a non-negative cooldown state for [param key].
func _init(key: StringName, duration: float, source_grant_handle_id: int = 0) -> void:
	_key = key
	_remaining = maxf(0.0, duration)
	_source_grant_handle_id = source_grant_handle_id

# ====== PUBLIC ========
## Decreases remaining time by a non-negative [param delta].
func advance(delta: float) -> void: _remaining = maxf(0.0, _remaining - maxf(delta, 0.0))
## Extends remaining time to at least [param duration].
func refresh(duration: float) -> void: _remaining = maxf(_remaining, duration)
## Returns whether the cooldown still blocks activation.
func is_active() -> bool: return _remaining > 0.0
## Returns the ability or shared-group cooldown key.
func get_key() -> StringName: return _key
## Returns remaining simulation seconds.
func get_remaining() -> float: return _remaining
## Returns the grant handle that started this cooldown.
func get_source_grant_handle_id() -> int: return _source_grant_handle_id
## Serializes cooldown diagnostics and snapshot-ready state.
func to_dictionary() -> Dictionary: return {"key": _key, "remaining": _remaining, "source_grant_handle_id": _source_grant_handle_id}
