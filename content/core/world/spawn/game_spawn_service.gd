extends Node
## World service that centralizes gameplay object spawning and despawning.
##
## Instantiates PackedScenes, validates their local kernel, initializes object
## composition, registers stable handles, and applies explicit despawn identity policy.
class_name GameSpawnService

## Emitted after a spawned object's kernel and handle are ready.
signal object_spawned(handle: GameObjectHandle)
## Emitted after a resolved or known object is despawned.
signal object_despawned(stable_id: StringName, reason: StringName)

# ======== EXPORT =========
@export var default_parent: Node = null
@export var object_resolver: GameObjectResolver = null

# ====== PUBLIC ========
## Instantiates and initializes a gameplay scene, returning its registered handle.
func spawn(scene_path: String, transform: Transform3D, execution_context: GameExecutionContext, parent: Node = null, stable_id: StringName = &"", region_id: StringName = &"") -> GameCommandResult:
	if scene_path.is_empty() or execution_context == null:
		return GameCommandResult.configuration_error(&"invalid_spawn_request", "Spawn request is incomplete.")
	var resource: Resource = load(scene_path)
	if not (resource is PackedScene):
		return GameCommandResult.configuration_error(&"invalid_spawn_scene", "Scene path is not a PackedScene.")
	var root: Node = (resource as PackedScene).instantiate()
	var target_parent: Node = parent if parent != null else default_parent
	if target_parent == null:
		root.queue_free()
		return GameCommandResult.invalid_target("Spawn service has no parent.")
	if root is Node3D:
		(root as Node3D).transform = transform
	var kernel: GameObjectKernel = null
	for child: Node in root.get_children():
		if child is GameObjectKernel:
			kernel = child as GameObjectKernel
			break
	if kernel == null:
		root.queue_free()
		return GameCommandResult.configuration_error(&"spawn_missing_kernel", "Spawned scene requires GameObjectKernel.")
	kernel.auto_initialize = false
	if not stable_id.is_empty():
		for child: Node in kernel.get_children():
			if child is GameObjectIdentity:
				(child as GameObjectIdentity).stable_id = stable_id
				break
	target_parent.add_child(root)
	var init_result: GameCommandResult = kernel.initialize_kernel()
	if not init_result.is_success():
		root.queue_free()
		return init_result
	var handle: GameObjectHandle = kernel.get_object_context().get_object_handle()
	if object_resolver != null:
		var register_result: GameCommandResult = object_resolver.register_handle(handle, StringName(scene_path), region_id, not stable_id.is_empty())
		if not register_result.is_success():
			root.queue_free()
			return register_result
	object_spawned.emit(handle)
	return GameCommandResult.success_changed(&"object_spawned", handle)

## Despawns an object and marks its stable handle unresolved or permanently invalid.
func despawn(handle: GameObjectHandle, reason: StringName = &"despawned", permanent: bool = false) -> GameCommandResult:
	if handle == null:
		return GameCommandResult.invalid_target("Despawn requires handle.")
	var stable_id: StringName = handle.get_stable_id()
	var root: Node = handle.get_root()
	if object_resolver != null:
		if permanent:
			object_resolver.invalidate_permanently(stable_id)
		else:
			object_resolver.mark_unresolved(stable_id)
	if root != null:
		root.queue_free()
	object_despawned.emit(stable_id, reason)
	return GameCommandResult.success_changed(&"object_despawned")
