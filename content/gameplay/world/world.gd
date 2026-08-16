extends Node3D
class_name GameWorldBase

# ======== EXPORT =========
@export var world_context: GameWorldContext = null

# ======== PRIVATE VAR ======
var _scheduled_kernel_ids: Dictionary = {}

# ======= OVERRIDE =======
func _ready() -> void:
	if world_context == null:
		push_error("GameWorldBase requires GameWorldContext.")
		return
	var scene_tree: SceneTree = get_tree()
	if not scene_tree.node_added.is_connected(_on_tree_node_added):
		scene_tree.node_added.connect(_on_tree_node_added)
	_bind_existing_kernels()

func _exit_tree() -> void:
	var scene_tree: SceneTree = get_tree()
	if scene_tree != null and scene_tree.node_added.is_connected(_on_tree_node_added):
		scene_tree.node_added.disconnect(_on_tree_node_added)
	_scheduled_kernel_ids.clear()

# ====== HELPERS ========
func _collect_kernels(node: Node, result: Array[GameObjectKernel]) -> void:
	for child: Node in node.get_children():
		if child is GameObjectKernel:
			result.append(child as GameObjectKernel)
		_collect_kernels(child, result)

func _bind_existing_kernels() -> void:
	var kernels: Array[GameObjectKernel] = []
	_collect_kernels(self, kernels)
	for kernel: GameObjectKernel in kernels:
		_bind_kernel(kernel)

func _bind_kernel_deferred(kernel: GameObjectKernel, instance_id: int) -> void:
	_scheduled_kernel_ids.erase(instance_id)
	if not is_instance_valid(kernel) or not is_ancestor_of(kernel):
		return
	_bind_kernel(kernel)

func _bind_kernel(kernel: GameObjectKernel) -> bool:
	if world_context == null or kernel == null:
		return false
	if kernel.get_lifecycle_state() != GameObjectKernel.LifecycleState.UNINITIALIZED:
		push_error(
			"GameWorldBase can only bind an uninitialized kernel. "
			+ "Disable GameObjectKernel.auto_initialize for world-bound objects."
		)
		return false
	var result: GameCommandResult = world_context.bind_kernel(kernel)
	if result.is_success():
		return true
	push_error(
		"Could not bind kernel: %s — %s" % [
			result.get_reason_code(),
			result.get_debug_message(),
		]
	)
	return false

# ====== PUBLIC ========
func bind_kernel(kernel: GameObjectKernel) -> bool:
	return _bind_kernel(kernel)

# ===== SLOTS =======
func _on_tree_node_added(node: Node) -> void:
	if not node is GameObjectKernel:
		return
	var kernel: GameObjectKernel = node as GameObjectKernel
	if not is_ancestor_of(kernel):
		return
	var instance_id: int = kernel.get_instance_id()
	if _scheduled_kernel_ids.has(instance_id):
		return
	_scheduled_kernel_ids[instance_id] = true
	call_deferred(&"_bind_kernel_deferred", kernel, instance_id)
