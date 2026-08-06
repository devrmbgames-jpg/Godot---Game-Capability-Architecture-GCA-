extends RefCounted
## Bounded in-memory diagnostics and execution trace store for one object kernel.
##
## The sink records structured messages and recent commands, events, and operations without
## treating ordinary gameplay rejection as an engine error.
class_name GameDiagnosticsSink

# ======= ENUMS =========
enum Level {
	TRACE,
	INFO,
	WARNING,
	ERROR,
	FATAL_CONFIGURATION_ERROR,
}

# ======== PRIVATE VAR ======
var _entries: Array[GameDiagnosticEntry] = []
var _recent_commands: Array[Dictionary] = []
var _recent_events: Array[Dictionary] = []
var _recent_operations: Array[Dictionary] = []
var _max_entries: int = 128

# ====== HELPERS ========
func _trim_array(values: Array, limit: int) -> void:
	while values.size() > limit:
		values.pop_front()

# ====== PUBLIC ========
## Changes the retained diagnostic entry limit, with a minimum of sixteen records.
func set_max_entries(max_entries: int) -> void:
	_max_entries = maxi(16, max_entries)
	_trim_array(_entries, _max_entries)

## Records one structured diagnostic message.
func record(level: int, code: StringName, message: String, context: Dictionary = {}) -> void:
	_entries.append(GameDiagnosticEntry.new(level, code, message, context))
	_trim_array(_entries, _max_entries)

## Appends a command and its result to the recent command trace.
func trace_command(command: GameCommand, result: GameCommandResult) -> void:
	var execution_context: GameExecutionContext = command.get_execution_context()
	_recent_commands.append({
		"command_type_id": command.get_command_type_id(),
		"required_capability_id": command.get_required_capability_id(),
		"sender": command.get_sender_handle().to_dictionary() if command.get_sender_handle() != null else {},
		"target": command.get_target_handle().to_dictionary() if command.get_target_handle() != null else {},
		"execution_context": execution_context.to_dictionary() if execution_context != null else {},
		"result": result.to_dictionary(),
	})
	_trim_array(_recent_commands, 32)

## Appends [param event] to the recent local event trace.
func trace_event(event: GameLocalEvent) -> void:
	_recent_events.append(event.to_dictionary())
	_trim_array(_recent_events, 32)

## Appends an operation lifecycle [param phase] and optional result to the recent trace.
func trace_operation(operation: GameOperation, phase: StringName, result: GameCommandResult = null) -> void:
	if operation == null:
		return
	var context: GameExecutionContext = operation.get_execution_context()
	_recent_operations.append({
		"phase": phase,
		"sequence": operation.get_sequence(),
		"operation_type": operation.get_operation_type(),
		"guard_key": operation.get_guard_key(),
		"context": context.to_dictionary() if context != null else {},
		"result": result.to_dictionary() if result != null else {},
	})
	_trim_array(_recent_operations, 64)

## Returns a shallow copy of retained diagnostic entries.
func get_entries() -> Array[GameDiagnosticEntry]:
	return _entries.duplicate()

## Returns messages and recent execution traces as a serializable diagnostic snapshot.
func get_debug_snapshot() -> Dictionary:
	var entries: Array[Dictionary] = []
	for entry: GameDiagnosticEntry in _entries:
		entries.append(entry.to_dictionary())
	return {
		"entries": entries,
		"recent_commands": _recent_commands.duplicate(true),
		"recent_events": _recent_events.duplicate(true),
		"recent_operations": _recent_operations.duplicate(true),
	}
