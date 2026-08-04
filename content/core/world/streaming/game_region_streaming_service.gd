extends Node
class_name GameRegionStreamingService

signal region_state_changed(region_id: StringName, state: int)

enum State { UNLOADED, LOADING, INITIALIZING, ACTIVE, DORMANT, UNLOADING, FAILED }
enum OfflinePolicy { FREEZE_WHILE_UNLOADED, ADVANCE_ELAPSED_DURATION, RESOLVE_ON_LOAD, UNSUPPORTED }

# ======== EXPORT =========
@export var object_resolver: GameObjectResolver = null

# ======== PRIVATE VAR ======
var _regions: Dictionary = {}

# ====== PUBLIC ========
func set_state(region_id: StringName, state: int, object_ids: Array[StringName] = []) -> void:
	_regions[region_id] = {"state": state, "object_ids": object_ids.duplicate()}
	region_state_changed.emit(region_id, state)

func request_load(region_id: StringName) -> GameCommandResult:
	if region_id.is_empty():
		return GameCommandResult.configuration_error(&"invalid_region_id", "Region ID is required.")
	set_state(region_id, State.LOADING)
	return GameCommandResult.success_changed(&"region_load_requested")

func request_unload(region_id: StringName) -> GameCommandResult:
	if not _regions.has(region_id):
		return GameCommandResult.rejected_permanent(&"unknown_region", "Region is unknown.")
	_regions[region_id].state = State.UNLOADING
	region_state_changed.emit(region_id, State.UNLOADING)
	return GameCommandResult.success_changed(&"region_unload_requested")

func complete_unload(region_id: StringName) -> GameCommandResult:
	if not _regions.has(region_id):
		return GameCommandResult.rejected_permanent(&"unknown_region", "Region is unknown.")
	if object_resolver != null:
		for object_id: StringName in _regions[region_id].object_ids:
			object_resolver.mark_unresolved(object_id)
	_regions[region_id].state = State.UNLOADED
	region_state_changed.emit(region_id, State.UNLOADED)
	return GameCommandResult.success_changed(&"region_unloaded")

func get_debug_snapshot() -> Dictionary:
	return _regions.duplicate(true)
