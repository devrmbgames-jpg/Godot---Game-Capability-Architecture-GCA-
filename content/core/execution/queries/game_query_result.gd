extends RefCounted
class_name GameQueryResult

# ======= ENUMS =========
enum Status {
    FOUND,
    NOT_FOUND,
    FAILED,
    INVALID_TARGET,
    MISSING_CAPABILITY,
    NOT_HANDLED,
}

# ======== PRIVATE VAR ======
var _status: int = Status.NOT_FOUND
var _reason_code: StringName = &""
var _debug_message: String = ""
var _value: Variant = null

# ======= OVERRIDE =======
func _init(status: int = Status.NOT_FOUND, reason_code: StringName = &"", debug_message: String = "", value: Variant = null) -> void:
    _status = status
    _reason_code = reason_code
    _debug_message = debug_message
    _value = value

# ====== PUBLIC ========
func is_found() -> bool:
    return _status == Status.FOUND

func is_failure() -> bool:
    return _status == Status.FAILED or _status == Status.INVALID_TARGET or _status == Status.MISSING_CAPABILITY

func get_status() -> int:
    return _status

func get_reason_code() -> StringName:
    return _reason_code

func get_debug_message() -> String:
    return _debug_message

func get_value() -> Variant:
    return _value

static func found_value(value: Variant) -> GameQueryResult:
    return GameQueryResult.new(Status.FOUND, &"found", "", value)

static func not_found(reason_code: StringName = &"not_found") -> GameQueryResult:
    return GameQueryResult.new(Status.NOT_FOUND, reason_code)

static func failure(reason_code: StringName, message: String) -> GameQueryResult:
    return GameQueryResult.new(Status.FAILED, reason_code, message)

static func invalid_target(message: String = "Query target is invalid.") -> GameQueryResult:
    return GameQueryResult.new(Status.INVALID_TARGET, &"invalid_target", message)

static func missing_capability(capability_id: StringName) -> GameQueryResult:
    return GameQueryResult.new(
        Status.MISSING_CAPABILITY,
        &"missing_capability",
        "Required capability '%s' is missing." % capability_id
    )

static func not_handled(query_type_id: StringName) -> GameQueryResult:
    return GameQueryResult.new(
        Status.NOT_HANDLED,
        &"query_not_handled",
        "No feature handled query '%s'." % query_type_id
    )
