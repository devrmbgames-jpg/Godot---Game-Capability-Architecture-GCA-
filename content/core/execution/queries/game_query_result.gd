extends RefCounted
## Structured outcome of a side-effect-free gameplay query.
##
## The result distinguishes a found value from absence, routing failure, invalid targets,
## missing capabilities, and unhandled query types.
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
## Creates a query result with optional diagnostic details and value.
func _init(status: int = Status.NOT_FOUND, reason_code: StringName = &"", debug_message: String = "", value: Variant = null) -> void:
	_status = status
	_reason_code = reason_code
	_debug_message = debug_message
	_value = value

# ====== PUBLIC ========
## Returns whether the query found a value.
func is_found() -> bool:
	return _status == Status.FOUND

## Returns whether the result represents a routing or contract failure.
func is_failure() -> bool:
	return _status == Status.FAILED or _status == Status.INVALID_TARGET or _status == Status.MISSING_CAPABILITY

## Returns the [enum Status] value.
func get_status() -> int:
	return _status

## Returns the stable machine-readable reason code.
func get_reason_code() -> StringName:
	return _reason_code

## Returns the developer-facing diagnostic message.
func get_debug_message() -> String:
	return _debug_message

## Returns the queried value, which may itself be [code]null[/code].
func get_value() -> Variant:
	return _value

## Creates a successful result containing [param value].
static func found_value(value: Variant) -> GameQueryResult:
	return GameQueryResult.new(Status.FOUND, &"found", "", value)

## Creates a result indicating that no matching value exists.
static func not_found(reason_code: StringName = &"not_found") -> GameQueryResult:
	return GameQueryResult.new(Status.NOT_FOUND, reason_code)

## Creates a query failure with [param reason_code] and [param message].
static func failure(reason_code: StringName, message: String) -> GameQueryResult:
	return GameQueryResult.new(Status.FAILED, reason_code, message)

## Creates an invalid-target query result.
static func invalid_target(message: String = "Query target is invalid.") -> GameQueryResult:
	return GameQueryResult.new(Status.INVALID_TARGET, &"invalid_target", message)

## Creates a missing-capability result for [param capability_id].
static func missing_capability(capability_id: StringName) -> GameQueryResult:
	return GameQueryResult.new(
		Status.MISSING_CAPABILITY,
		&"missing_capability",
		"Required capability '%s' is missing." % capability_id
	)

## Creates a result indicating no feature accepted [param query_type_id].
static func not_handled(query_type_id: StringName) -> GameQueryResult:
	return GameQueryResult.new(
		Status.NOT_HANDLED,
		&"query_not_handled",
		"No feature handled query '%s'." % query_type_id
	)
