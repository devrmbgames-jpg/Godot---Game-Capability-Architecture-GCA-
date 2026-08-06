extends RefCounted
## Carries causal, ownership, targeting, and deterministic metadata through gameplay chains.
##
## Root and parent operation IDs remain stable across child abilities, effects, commands, and
## events so diagnostics can reconstruct cross-object execution without strong node references.
class_name GameExecutionContext

# ======== PRIVATE VAR ======
var _operation_id: int = 0
var _root_operation_id: int = 0
var _parent_operation_id: int = 0
var _source_handle: GameObjectHandle = null
var _instigator_handle: GameObjectHandle = null
var _current_owner_handle: GameObjectHandle = null
var _target_handles: Array[GameObjectHandle] = []
var _cause_type: StringName = &""
var _context_tags: Array[StringName] = []
var _chain_depth: int = 0
var _deterministic_seed: int = 0
var _simulation_step: int = 0
var _captured_values: Dictionary = {}
var _debug_label: String = ""

# ====== HELPERS ========
static func _derive_seed(parent_seed: int, operation_id: int, depth: int) -> int:
	var mixed: int = parent_seed ^ (operation_id * 1103515245) ^ (depth * 12345)
	return abs(mixed) & 0x7fffffff

# ====== PUBLIC ========
## Creates a new root execution chain owned by [param owner_handle].
static func create_root(
	operation_id: int,
	owner_handle: GameObjectHandle,
	cause_type: StringName,
	deterministic_seed: int,
	simulation_step: int = 0,
	debug_label: String = ""
) -> GameExecutionContext:
	var context := GameExecutionContext.new()
	context._operation_id = operation_id
	context._root_operation_id = operation_id
	context._current_owner_handle = owner_handle
	context._source_handle = owner_handle
	context._instigator_handle = owner_handle
	context._cause_type = cause_type
	context._deterministic_seed = deterministic_seed
	context._simulation_step = simulation_step
	context._debug_label = debug_label
	return context

## Creates a child context that inherits the current chain and increments depth.
func create_child(
	operation_id: int,
	owner_handle: GameObjectHandle = null,
	cause_type: StringName = &"",
	debug_label: String = ""
) -> GameExecutionContext:
	var child := GameExecutionContext.new()
	child._operation_id = operation_id
	child._root_operation_id = _root_operation_id
	child._parent_operation_id = _operation_id
	child._source_handle = _source_handle
	child._instigator_handle = _instigator_handle
	child._current_owner_handle = owner_handle if owner_handle != null else _current_owner_handle
	child._target_handles = _target_handles.duplicate()
	child._cause_type = cause_type if not cause_type.is_empty() else _cause_type
	child._context_tags = _context_tags.duplicate()
	child._chain_depth = _chain_depth + 1
	child._deterministic_seed = _derive_seed(_deterministic_seed, operation_id, child._chain_depth)
	child._simulation_step = _simulation_step
	child._captured_values = _captured_values.duplicate(true)
	child._debug_label = debug_label
	return child

## Returns this operation's unique ID.
func get_operation_id() -> int:
	return _operation_id

## Returns the root operation ID shared by the whole chain.
func get_root_operation_id() -> int:
	return _root_operation_id

## Returns the immediate parent operation ID, or zero for a root context.
func get_parent_operation_id() -> int:
	return _parent_operation_id

## Returns the logical source handle.
func get_source_handle() -> GameObjectHandle:
	return _source_handle

## Replaces the logical source handle explicitly.
func set_source_handle(handle: GameObjectHandle) -> void:
	_source_handle = handle

## Returns the instigator handle responsible for initiating the chain.
func get_instigator_handle() -> GameObjectHandle:
	return _instigator_handle

## Replaces the instigator handle explicitly.
func set_instigator_handle(handle: GameObjectHandle) -> void:
	_instigator_handle = handle

## Returns the object handle currently owning this operation.
func get_current_owner_handle() -> GameObjectHandle:
	return _current_owner_handle

## Replaces target handles with a defensive copy of [param handles].
func set_target_handles(handles: Array[GameObjectHandle]) -> void:
	_target_handles = handles.duplicate()

## Returns a copy of current target handles.
func get_target_handles() -> Array[GameObjectHandle]:
	return _target_handles.duplicate()

## Returns the stable cause type for this operation.
func get_cause_type() -> StringName:
	return _cause_type

## Adds [param tag_id] to inherited context tags when not already present.
func add_context_tag(tag_id: StringName) -> void:
	if tag_id not in _context_tags:
		_context_tags.append(tag_id)

## Returns a copy of inherited context tags.
func get_context_tags() -> Array[StringName]:
	return _context_tags.duplicate()

## Returns this operation's depth below the root context.
func get_chain_depth() -> int:
	return _chain_depth

## Returns the deterministic seed assigned to this operation.
func get_deterministic_seed() -> int:
	return _deterministic_seed

## Returns the simulation step captured when the root context was created.
func get_simulation_step() -> int:
	return _simulation_step

## Stores a snapshot value under [param key].
func set_captured_value(key: StringName, value: Variant) -> void:
	_captured_values[key] = value

## Returns a captured value or [param default_value] when absent.
func get_captured_value(key: StringName, default_value: Variant = null) -> Variant:
	return _captured_values.get(key, default_value)

## Returns the developer-facing label for this operation.
func get_debug_label() -> String:
	return _debug_label

## Returns a serializable diagnostic representation of the execution chain state.
func to_dictionary() -> Dictionary:
	var target_snapshots: Array[Dictionary] = []
	for target_handle: GameObjectHandle in _target_handles:
		target_snapshots.append(target_handle.to_dictionary() if target_handle != null else {})
	return {
		"operation_id": _operation_id,
		"root_operation_id": _root_operation_id,
		"parent_operation_id": _parent_operation_id,
		"source": _source_handle.to_dictionary() if _source_handle != null else {},
		"instigator": _instigator_handle.to_dictionary() if _instigator_handle != null else {},
		"current_owner": _current_owner_handle.to_dictionary() if _current_owner_handle != null else {},
		"targets": target_snapshots,
		"cause_type": _cause_type,
		"chain_depth": _chain_depth,
		"deterministic_seed": _deterministic_seed,
		"simulation_step": _simulation_step,
		"context_tags": _context_tags.duplicate(),
		"captured_values": _captured_values.duplicate(true),
		"debug_label": _debug_label,
	}
