extends RefCounted
class_name GameDiagnosticEntry

# ======== PRIVATE VAR ======
var _level: int = 0
var _code: StringName = &""
var _message: String = ""
var _context: Dictionary = {}
var _timestamp_usec: int = 0

# ======= OVERRIDE =======
func _init(level: int = 0, code: StringName = &"", message: String = "", context: Dictionary = {}) -> void:
    _level = level
    _code = code
    _message = message
    _context = context.duplicate(true)
    _timestamp_usec = Time.get_ticks_usec()

# ====== PUBLIC ========
func to_dictionary() -> Dictionary:
    return {
        "level": _level,
        "code": _code,
        "message": _message,
        "context": _context.duplicate(true),
        "timestamp_usec": _timestamp_usec,
    }
