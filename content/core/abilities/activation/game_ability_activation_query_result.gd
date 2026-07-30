extends RefCounted
class_name GameAbilityActivationQueryResult

# ======== PRIVATE VAR ======
var _available: bool = false
var _reason_code: StringName = &""
var _debug_message: String = ""
var _grant_handle_id: int = 0
var _cooldown_remaining: float = 0.0
var _details: Dictionary = {}

# ======= OVERRIDE =======
func _init(available: bool = false, reason_code: StringName = &"", debug_message: String = "", grant_handle_id: int = 0, cooldown_remaining: float = 0.0, details: Dictionary = {}) -> void:
	_available = available
	_reason_code = reason_code
	_debug_message = debug_message
	_grant_handle_id = grant_handle_id
	_cooldown_remaining = cooldown_remaining
	_details = details.duplicate(true)

# ====== PUBLIC ========
func is_available() -> bool: return _available
func get_reason_code() -> StringName: return _reason_code
func get_debug_message() -> String: return _debug_message
func get_grant_handle_id() -> int: return _grant_handle_id
func get_cooldown_remaining() -> float: return _cooldown_remaining
func get_details() -> Dictionary: return _details.duplicate(true)
func to_dictionary() -> Dictionary:
	return {"available": _available, "reason_code": _reason_code, "debug_message": _debug_message, "grant_handle_id": _grant_handle_id, "cooldown_remaining": _cooldown_remaining, "details": _details.duplicate(true)}

static func available(grant_handle_id: int, details: Dictionary = {}) -> GameAbilityActivationQueryResult:
	return GameAbilityActivationQueryResult.new(true, &"available", "", grant_handle_id, 0.0, details)

static func unavailable(reason_code: StringName, message: String, grant_handle_id: int = 0, cooldown_remaining: float = 0.0, details: Dictionary = {}) -> GameAbilityActivationQueryResult:
	return GameAbilityActivationQueryResult.new(false, reason_code, message, grant_handle_id, cooldown_remaining, details)
