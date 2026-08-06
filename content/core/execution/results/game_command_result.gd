extends RefCounted
## Structured outcome of an addressed gameplay command or mutation operation.
##
## Results distinguish successful changes, gameplay rejection, missing contracts, invalid
## targets, cancellation, queue guards, and configuration faults for callers, UI, AI, and tests.
class_name GameCommandResult

# ======= ENUMS =========
enum Status {
	SUCCESS_CHANGED,
	SUCCESS_UNCHANGED,
	REJECTED_TEMPORARY,
	REJECTED_PERMANENT,
	MISSING_CAPABILITY,
	INVALID_TARGET,
	BLOCKED_BY_TAG,
	INSUFFICIENT_RESOURCE,
	COOLDOWN_ACTIVE,
	CANCELLED,
	CONFIGURATION_ERROR,
	QUEUE_LIMIT,
	CYCLE_GUARD,
	NOT_HANDLED,
}

# ======== PRIVATE VAR ======
var _status: int = Status.SUCCESS_UNCHANGED
var _reason_code: StringName = &""
var _debug_message: String = ""
var _source_operation_id: int = 0
var _payload: Variant = null
var _produced_items: Array[Variant] = []

# ======= OVERRIDE =======
## Creates a command result with optional payload and produced runtime items.
func _init(
	status: int = Status.SUCCESS_UNCHANGED,
	reason_code: StringName = &"",
	debug_message: String = "",
	source_operation_id: int = 0,
	payload: Variant = null,
	produced_items: Array[Variant] = []
) -> void:
	_status = status
	_reason_code = reason_code
	_debug_message = debug_message
	_source_operation_id = source_operation_id
	_payload = payload
	_produced_items = produced_items.duplicate()

# ====== PUBLIC ========
## Returns whether this result represents successful handling.
func is_success() -> bool:
	return _status == Status.SUCCESS_CHANGED or _status == Status.SUCCESS_UNCHANGED

## Returns whether this result reports invalid project or scene configuration.
func is_configuration_error() -> bool:
	return _status == Status.CONFIGURATION_ERROR

## Returns the [enum Status] value.
func get_status() -> int:
	return _status

## Returns the stable machine-readable reason code.
func get_reason_code() -> StringName:
	return _reason_code

## Returns the developer-facing diagnostic message.
func get_debug_message() -> String:
	return _debug_message

## Returns the operation ID that produced this result.
func get_source_operation_id() -> int:
	return _source_operation_id

## Returns the optional result payload.
func get_payload() -> Variant:
	return _payload

## Returns a copy of operations, handles, or runtime values produced by this command.
func get_produced_items() -> Array[Variant]:
	return _produced_items.duplicate()

## Assigns [param operation_id] when no source operation has been attached yet.
func attach_source_operation_id(operation_id: int) -> GameCommandResult:
	if _source_operation_id == 0:
		_source_operation_id = operation_id
	return self

## Appends [param item] to the produced item collection.
func add_produced_item(item: Variant) -> void:
	_produced_items.append(item)

## Returns a serializable diagnostic representation of this result.
func to_dictionary() -> Dictionary:
	return {
		"status": _status,
		"reason_code": _reason_code,
		"debug_message": _debug_message,
		"source_operation_id": _source_operation_id,
		"payload": _payload,
		"produced_items": _produced_items.duplicate(),
	}

## Creates a successful result indicating gameplay state changed.
static func success_changed(reason_code: StringName = &"success_changed", payload: Variant = null) -> GameCommandResult:
	return GameCommandResult.new(Status.SUCCESS_CHANGED, reason_code, "", 0, payload)

## Creates a successful result indicating no gameplay state changed.
static func success_unchanged(reason_code: StringName = &"success_unchanged", payload: Variant = null) -> GameCommandResult:
	return GameCommandResult.new(Status.SUCCESS_UNCHANGED, reason_code, "", 0, payload)

## Creates a retryable gameplay rejection.
static func rejected_temporary(reason_code: StringName, message: String, payload: Variant = null) -> GameCommandResult:
	return GameCommandResult.new(Status.REJECTED_TEMPORARY, reason_code, message, 0, payload)

## Creates a non-retryable gameplay rejection.
static func rejected_permanent(reason_code: StringName, message: String, payload: Variant = null) -> GameCommandResult:
	return GameCommandResult.new(Status.REJECTED_PERMANENT, reason_code, message, 0, payload)

## Creates a missing-capability result for [param capability_id].
static func missing_capability(capability_id: StringName) -> GameCommandResult:
	return GameCommandResult.new(
		Status.MISSING_CAPABILITY,
		&"missing_capability",
		"Required capability '%s' is missing." % capability_id
	)

## Creates an invalid-target result with an optional diagnostic [param message].
static func invalid_target(message: String = "Command target is invalid.") -> GameCommandResult:
	return GameCommandResult.new(Status.INVALID_TARGET, &"invalid_target", message)

## Creates a fatal configuration result.
static func configuration_error(reason_code: StringName, message: String) -> GameCommandResult:
	return GameCommandResult.new(Status.CONFIGURATION_ERROR, reason_code, message)

## Creates a result indicating no feature accepted [param command_type_id].
static func not_handled(command_type_id: StringName) -> GameCommandResult:
	return GameCommandResult.new(
		Status.NOT_HANDLED,
		&"command_not_handled",
		"No feature handled command '%s'." % command_type_id
	)
