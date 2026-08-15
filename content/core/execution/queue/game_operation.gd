extends RefCounted
## Base runtime operation executed by [GameExecutionQueue].
##
## Operations carry deterministic sequence and cycle-guard metadata. Subclasses override
## [method execute] and optionally [method cancel] without storing mutable state in definitions.
class_name GameOperation

# ======== PRIVATE VAR ======
var _operation_type: StringName = &""
var _source_definition_id: StringName = &""
var _target_handle: GameObjectHandle = null
var _trigger_key: StringName = &""
var _execution_context: GameExecutionContext = null
var _debug_label: String = ""
var _sequence: int = 0

# ======= OVERRIDE =======
## Creates an operation and its cycle-guard metadata.
func _init(
	operation_type: StringName = &"",
	execution_context: GameExecutionContext = null,
	source_definition_id: StringName = &"",
	target_handle: GameObjectHandle = null,
	trigger_key: StringName = &"",
	debug_label: String = ""
) -> void:
	_operation_type = operation_type
	_execution_context = execution_context
	_source_definition_id = source_definition_id
	_target_handle = target_handle
	_trigger_key = trigger_key
	_debug_label = debug_label

# ====== PUBLIC ========
## Virtual execution hook. The default operation succeeds without changing state.
func execute(_context: GameExecutionContext) -> GameCommandResult:
	return GameCommandResult.success_unchanged(&"operation_noop")

## Virtual cancellation hook called when the queue cancels this operation.
func cancel(_reason: StringName) -> void:
	pass

## Assigns the deterministic queue [param sequence].
func set_sequence(sequence: int) -> void:
	_sequence = sequence

## Returns the deterministic queue sequence.
func get_sequence() -> int:
	return _sequence

## Returns the stable operation type identifier.
func get_operation_type() -> StringName:
	return _operation_type

## Returns the definition ID associated with this operation.
func get_source_definition_id() -> StringName:
	return _source_definition_id

## Returns the target handle used by the cycle guard.
func get_target_handle() -> GameObjectHandle:
	return _target_handle

## Returns the configured trigger key used by the cycle guard.
func get_trigger_key() -> StringName:
	return _trigger_key

## Returns the operation execution context.
func get_execution_context() -> GameExecutionContext:
	return _execution_context

## Returns the developer-facing operation label.
func get_debug_label() -> String:
	return _debug_label

## Returns a stable compound key used to limit repeated operations in one root chain.
func get_guard_key() -> String:
	var target_id: String = "none"
	if _target_handle != null:
		target_id = str(_target_handle.get_stable_id())
		if target_id.is_empty():
			target_id = str(_target_handle.get_runtime_instance_id())
	return "%s|%s|%s|%s" % [_operation_type, _source_definition_id, target_id, _trigger_key]
