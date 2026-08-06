extends RefCounted
## Immutable record of a gameplay fact delivered within one local object kernel.
##
## Events report completed state changes upward; they are not commands and must retain the
## source handle and execution chain that caused the fact.
class_name GameLocalEvent

# ======== PRIVATE VAR ======
var _event_type_id: StringName = &""
var _source_handle: GameObjectHandle = null
var _execution_context: GameExecutionContext = null
var _payload: Variant = null
var _sequence: int = 0

# ======= OVERRIDE =======
## Creates a local event with an optional payload.
func _init(
	event_type_id: StringName = &"",
	source_handle: GameObjectHandle = null,
	execution_context: GameExecutionContext = null,
	payload: Variant = null
) -> void:
	_event_type_id = event_type_id
	_source_handle = source_handle
	_execution_context = execution_context
	_payload = payload

# ====== PUBLIC ========
## Returns the stable event type identifier.
func get_event_type_id() -> StringName:
	return _event_type_id

## Returns the object handle that published the event.
func get_source_handle() -> GameObjectHandle:
	return _source_handle

## Returns the causal execution context.
func get_execution_context() -> GameExecutionContext:
	return _execution_context

## Returns the event payload without transforming it.
func get_payload() -> Variant:
	return _payload

## Assigns the deterministic local delivery [param sequence].
func set_sequence(sequence: int) -> void:
	_sequence = sequence

## Returns the local delivery sequence assigned by the kernel.
func get_sequence() -> int:
	return _sequence

## Returns a serializable diagnostic representation of this event.
func to_dictionary() -> Dictionary:
	return {
		"event_type_id": _event_type_id,
		"sequence": _sequence,
		"payload": _payload,
		"execution_context": _execution_context.to_dictionary() if _execution_context != null else {},
	}
