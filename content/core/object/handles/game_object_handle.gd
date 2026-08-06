extends RefCounted
## Streaming-aware stable reference to one gameplay object.
##
## Keeps persistent identity separate from weak runtime references and exposes
## explicit resolved, unresolved, loading, permanently invalid, and expired states.
class_name GameObjectHandle

# ======= ENUMS =========
enum State {
	RESOLVED,
	UNRESOLVED_KNOWN,
	LOADING_REQUESTED,
	INVALID_PERMANENT,
	EPHEMERAL_EXPIRED,
}

# ======== PRIVATE VAR ======
var _stable_id: StringName = &""
var _runtime_instance_id: int = 0
var _root_reference: WeakRef = null
var _kernel_reference: WeakRef = null
var _state: int = State.UNRESOLVED_KNOWN

# ======= OVERRIDE =======
## Creates an unresolved handle with optional stable and runtime identity.
func _init(stable_id: StringName = &"", runtime_instance_id: int = 0) -> void:
	_stable_id = stable_id
	_runtime_instance_id = runtime_instance_id

# ====== PUBLIC ========
## Resolves the handle to weak root and kernel references.
func resolve(root: Node, kernel: GameObjectKernel) -> void:
	_root_reference = weakref(root)
	_kernel_reference = weakref(kernel)
	_runtime_instance_id = root.get_instance_id()
	_state = State.RESOLVED

## Marks the handle permanently invalid.
func invalidate() -> void:
	mark_invalid_permanent()

## Removes runtime references while preserving known stable identity.
func mark_unresolved_known() -> void:
	_root_reference = null
	_kernel_reference = null
	_runtime_instance_id = 0
	_state = State.UNRESOLVED_KNOWN

## Marks that the world layer has requested loading for this identity.
func mark_loading_requested() -> void:
	_root_reference = null
	_kernel_reference = null
	_runtime_instance_id = 0
	_state = State.LOADING_REQUESTED

## Permanently invalidates the handle and clears runtime references.
func mark_invalid_permanent() -> void:
	_root_reference = null
	_kernel_reference = null
	_runtime_instance_id = 0
	_state = State.INVALID_PERMANENT

## Marks an ephemeral object as expired and non-resolvable.
func mark_ephemeral_expired() -> void:
	_root_reference = null
	_kernel_reference = null
	_runtime_instance_id = 0
	_state = State.EPHEMERAL_EXPIRED

## Returns whether both weak references are currently valid.
func is_resolved() -> bool:
	return _state == State.RESOLVED and get_root() != null and get_kernel() != null

## Returns whether the identity can no longer be resolved.
func is_invalidated() -> bool:
	return _state == State.INVALID_PERMANENT or _state == State.EPHEMERAL_EXPIRED

## Returns whether this stable identity is known and not permanently invalid.
func is_known() -> bool:
	return not _stable_id.is_empty() and _state != State.INVALID_PERMANENT and _state != State.EPHEMERAL_EXPIRED

## Returns the current [enum State].
func get_state() -> int:
	return _state

## Returns persistent object identity.
func get_stable_id() -> StringName:
	return _stable_id

## Replaces persistent object identity before registration.
func set_stable_id(stable_id: StringName) -> void:
	_stable_id = stable_id

## Returns the current SceneTree instance ID, or [code]0[/code] when unresolved.
func get_runtime_instance_id() -> int:
	return _runtime_instance_id

## Returns the weakly referenced object root, or [code]null[/code].
func get_root() -> Node:
	if _root_reference == null:
		return null
	return _root_reference.get_ref() as Node

## Returns the weakly referenced local kernel, or [code]null[/code].
func get_kernel() -> GameObjectKernel:
	if _kernel_reference == null:
		return null
	return _kernel_reference.get_ref() as GameObjectKernel

## Returns the resolved object's local context, or [code]null[/code].
func get_context() -> GameObjectContext:
	var kernel: GameObjectKernel = get_kernel()
	return kernel.get_object_context() if kernel != null else null

## Serializes stable identity, runtime identity, and resolution state.
func to_dictionary() -> Dictionary:
	return {
		"stable_id": _stable_id,
		"runtime_instance_id": _runtime_instance_id,
		"state": _state,
		"resolved": is_resolved(),
		"invalidated": is_invalidated(),
	}
