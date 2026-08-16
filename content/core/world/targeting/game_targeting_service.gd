extends Node
## Performs deterministic world-space target queries over resolved GCA object handles.
##
## The service returns handles and query metadata instead of exposing raw scene nodes to
## abilities, AI, or interaction systems. Candidates are ordered by distance and stable ID.
class_name GameTargetingService

# ======== EXPORT =========
@export var object_resolver: GameObjectResolver = null

# ======== PRIVATE VAR ======
var _query_version: int = 0

# ====== PUBLIC ========
## Finds resolved objects inside a sphere around [param origin].
##
## Candidates may be filtered by [param required_capability], [param required_tags], and
## stable IDs in [param excluded_ids]. A positive [param maximum_count] truncates the
## deterministically sorted result. Returns [code]handles[/code], parallel
## [code]metadata[/code], and a monotonically increasing [code]query_version[/code].
func query_sphere(origin: Vector3, radius: float, required_capability: StringName = &"", required_tags: Array[StringName] = [], excluded_ids: Array[StringName] = [], maximum_count: int = 0) -> Dictionary:
	_query_version += 1
	var candidates: Array[Dictionary] = []
	if object_resolver == null:
		return {&"handles": [], &"metadata": [], &"query_version": _query_version}
	for handle: GameObjectHandle in object_resolver.get_resolved_handles():
		if handle.get_stable_id() in excluded_ids or not (handle.get_root() is Node3D):
			continue
		var context: GameObjectContext = handle.get_context()
		if context == null:
			continue
		if not required_capability.is_empty() and context.get_capability(required_capability) == null:
			continue
		var valid: bool = true
		for tag_id: StringName in required_tags:
			if not context.has_tag_or_child(tag_id):
				valid = false
				break
		if not valid:
			continue
		var point: Vector3 = (handle.get_root() as Node3D).global_position
		var distance: float = origin.distance_to(point)
		if distance <= radius:
			candidates.append({&"handle": handle, &"distance": distance, &"point": point, &"stable_id": handle.get_stable_id()})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a[&"distance"]), float(b[&"distance"])):
			return float(a[&"distance"]) < float(b[&"distance"])
		return String(a[&"stable_id"]) < String(b[&"stable_id"]))
	if maximum_count > 0 and candidates.size() > maximum_count:
		candidates.resize(maximum_count)
	var handles: Array[GameObjectHandle] = []
	var metadata: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		handles.append(candidate[&"handle"])
		metadata.append({&"distance": candidate[&"distance"], &"point": candidate[&"point"], &"stable_id": candidate[&"stable_id"]})
	return {&"handles": handles, &"metadata": metadata, &"query_version": _query_version}
