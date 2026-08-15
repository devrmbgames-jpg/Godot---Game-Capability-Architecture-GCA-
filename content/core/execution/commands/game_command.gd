extends RefCounted
## Immutable addressed request to change gameplay state through a target kernel.
##
## A command carries stable sender and target handles, a causal execution context, an
## optional typed payload, routing capability, flags, and correlation metadata.
class_name GameCommand

# ======== PRIVATE VAR ======
var _command_type_id: StringName = &""
var _sender_handle: GameObjectHandle = null
var _target_handle: GameObjectHandle = null
var _execution_context: GameExecutionContext = null
var _payload: Variant = null
var _flags: int = 0
var _correlation_id: StringName = &""
var _required_capability_id: StringName = &""

# ======= OVERRIDE =======
## Creates an addressed gameplay command.
func _init(
	command_type_id: StringName = &"",
	sender_handle: GameObjectHandle = null,
	target_handle: GameObjectHandle = null,
	execution_context: GameExecutionContext = null,
	payload: Variant = null,
	required_capability_id: StringName = &"",
	flags: int = 0,
	correlation_id: StringName = &""
) -> void:
	_command_type_id = command_type_id
	_sender_handle = sender_handle
	_target_handle = target_handle
	_execution_context = execution_context
	_payload = payload
	_required_capability_id = required_capability_id
	_flags = flags
	_correlation_id = correlation_id

# ====== PUBLIC ========
## Returns the stable command type identifier.
func get_command_type_id() -> StringName:
	return _command_type_id

## Returns the command sender handle.
func get_sender_handle() -> GameObjectHandle:
	return _sender_handle

## Returns the explicit target handle.
func get_target_handle() -> GameObjectHandle:
	return _target_handle

## Returns the causal execution context.
func get_execution_context() -> GameExecutionContext:
	return _execution_context

## Returns the command payload without transforming it.
func get_payload() -> Variant:
	return _payload

## Returns command-specific execution flags.
func get_flags() -> int:
	return _flags

## Returns the optional external correlation identifier.
func get_correlation_id() -> StringName:
	return _correlation_id

## Returns the capability used to restrict candidate handlers, or an empty ID.
func get_required_capability_id() -> StringName:
	return _required_capability_id
