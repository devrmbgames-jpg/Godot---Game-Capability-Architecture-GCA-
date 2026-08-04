extends RefCounted
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
func _init(stable_id: StringName = &"", runtime_instance_id: int = 0) -> void:
	_stable_id = stable_id
	_runtime_instance_id = runtime_instance_id

# ====== PUBLIC ========
func resolve(root: Node, kernel: GameObjectKernel) -> void:
	_root_reference = weakref(root)
	_kernel_reference = weakref(kernel)
	_runtime_instance_id = root.get_instance_id()
	_state = State.RESOLVED

func invalidate() -> void:
	mark_invalid_permanent()

func mark_unresolved_known() -> void:
	_root_reference = null
	_kernel_reference = null
	_runtime_instance_id = 0
	_state = State.UNRESOLVED_KNOWN

func mark_loading_requested() -> void:
	_root_reference = null
	_kernel_reference = null
	_runtime_instance_id = 0
	_state = State.LOADING_REQUESTED

func mark_invalid_permanent() -> void:
	_root_reference = null
	_kernel_reference = null
	_runtime_instance_id = 0
	_state = State.INVALID_PERMANENT

func mark_ephemeral_expired() -> void:
	_root_reference = null
	_kernel_reference = null
	_runtime_instance_id = 0
	_state = State.EPHEMERAL_EXPIRED

func is_resolved() -> bool:
	return _state == State.RESOLVED and get_root() != null and get_kernel() != null

func is_invalidated() -> bool:
	return _state == State.INVALID_PERMANENT or _state == State.EPHEMERAL_EXPIRED

func is_known() -> bool:
	return not _stable_id.is_empty() and _state != State.INVALID_PERMANENT and _state != State.EPHEMERAL_EXPIRED

func get_state() -> int:
	return _state

func get_stable_id() -> StringName:
	return _stable_id

func set_stable_id(stable_id: StringName) -> void:
	_stable_id = stable_id

func get_runtime_instance_id() -> int:
	return _runtime_instance_id

func get_root() -> Node:
	if _root_reference == null:
		return null
	return _root_reference.get_ref() as Node

func get_kernel() -> GameObjectKernel:
	if _kernel_reference == null:
		return null
	return _kernel_reference.get_ref() as GameObjectKernel

func get_context() -> GameObjectContext:
	var kernel: GameObjectKernel = get_kernel()
	return kernel.get_object_context() if kernel != null else null

func to_dictionary() -> Dictionary:
	return {
		"stable_id": _stable_id,
		"runtime_instance_id": _runtime_instance_id,
		"state": _state,
		"resolved": is_resolved(),
		"invalidated": is_invalidated(),
	}
