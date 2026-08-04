extends Node
class_name GameObjectResolver

signal object_resolved(stable_id: StringName, handle: GameObjectHandle)
signal object_unresolved(stable_id: StringName, handle: GameObjectHandle)
signal object_invalidated(stable_id: StringName)

# ======== PRIVATE VAR ======
var _handles: Dictionary = {}
var _metadata: Dictionary = {}

# ====== PUBLIC ========
func register_handle(handle: GameObjectHandle, scene_id: StringName = &"", region_id: StringName = &"", persistent: bool = false) -> GameCommandResult:
	if handle == null or handle.get_stable_id().is_empty() or not handle.is_resolved():
		return GameCommandResult.configuration_error(&"invalid_world_handle", "Resolver requires a resolved stable handle.")
	var stable_id: StringName = handle.get_stable_id()
	var canonical: GameObjectHandle = _handles.get(stable_id) as GameObjectHandle
	if canonical == null:
		canonical = handle
		_handles[stable_id] = canonical
	elif canonical != handle:
		canonical.resolve(handle.get_root(), handle.get_kernel())
	_metadata[stable_id] = {"scene_id": scene_id, "region_id": region_id, "persistent": persistent}
	object_resolved.emit(stable_id, canonical)
	return GameCommandResult.success_changed(&"world_object_registered", canonical)

func register_known(stable_id: StringName, scene_id: StringName = &"", region_id: StringName = &"") -> GameObjectHandle:
	if stable_id.is_empty(): return null
	var handle: GameObjectHandle = _handles.get(stable_id) as GameObjectHandle
	if handle == null:
		handle = GameObjectHandle.new(stable_id)
		handle.mark_unresolved_known()
		_handles[stable_id] = handle
	_metadata[stable_id] = {"scene_id": scene_id, "region_id": region_id}
	return handle

func resolve(stable_id: StringName) -> GameObjectHandle:
	return _handles.get(stable_id) as GameObjectHandle

func mark_unresolved(stable_id: StringName) -> GameCommandResult:
	var handle: GameObjectHandle = resolve(stable_id)
	if handle == null: return GameCommandResult.rejected_permanent(&"unknown_world_object", "Object is not registered.")
	handle.mark_unresolved_known()
	object_unresolved.emit(stable_id, handle)
	return GameCommandResult.success_changed(&"world_object_unresolved", handle)

func request_load(stable_id: StringName) -> GameCommandResult:
	var handle: GameObjectHandle = resolve(stable_id)
	if handle == null: return GameCommandResult.rejected_permanent(&"unknown_world_object", "Object is not registered.")
	if handle.is_resolved(): return GameCommandResult.success_unchanged(&"already_resolved", handle)
	handle.mark_loading_requested()
	return GameCommandResult.success_changed(&"load_requested", handle)

func invalidate_permanently(stable_id: StringName) -> GameCommandResult:
	var handle: GameObjectHandle = resolve(stable_id)
	if handle == null: return GameCommandResult.success_unchanged(&"already_unknown")
	handle.mark_invalid_permanent()
	object_invalidated.emit(stable_id)
	return GameCommandResult.success_changed(&"object_invalidated")

func get_resolved_handles() -> Array[GameObjectHandle]:
	var result: Array[GameObjectHandle] = []
	for handle: GameObjectHandle in _handles.values():
		if handle.is_resolved(): result.append(handle)
	result.sort_custom(func(a: GameObjectHandle, b: GameObjectHandle) -> bool: return String(a.get_stable_id()) < String(b.get_stable_id()))
	return result

func get_debug_snapshot() -> Dictionary:
	var states: Dictionary = {}
	for stable_id: StringName in _handles.keys(): states[stable_id] = (_handles[stable_id] as GameObjectHandle).to_dictionary()
	return {"handles": states, "metadata": _metadata.duplicate(true)}
