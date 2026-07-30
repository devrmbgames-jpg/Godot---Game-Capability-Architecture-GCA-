extends RefCounted
class_name GameObjectHandle

# ======== PRIVATE VAR ======
var _stable_id: StringName = &""
var _runtime_instance_id: int = 0
var _root_reference: WeakRef = null
var _kernel_reference: WeakRef = null
var _invalidated: bool = false

# ======= OVERRIDE =======
func _init(stable_id: StringName = &"", runtime_instance_id: int = 0) -> void:
    _stable_id = stable_id
    _runtime_instance_id = runtime_instance_id

# ====== PUBLIC ========
func resolve(root: Node, kernel: GameObjectKernel) -> void:
    _root_reference = weakref(root)
    _kernel_reference = weakref(kernel)
    _runtime_instance_id = root.get_instance_id()
    _invalidated = false

func invalidate() -> void:
    _root_reference = null
    _kernel_reference = null
    _invalidated = true

func is_resolved() -> bool:
    return not _invalidated and get_root() != null and get_kernel() != null

func is_invalidated() -> bool:
    return _invalidated

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
    if kernel == null:
        return null
    return kernel.get_object_context()

func to_dictionary() -> Dictionary:
    return {
        "stable_id": _stable_id,
        "runtime_instance_id": _runtime_instance_id,
        "resolved": is_resolved(),
        "invalidated": _invalidated,
    }
