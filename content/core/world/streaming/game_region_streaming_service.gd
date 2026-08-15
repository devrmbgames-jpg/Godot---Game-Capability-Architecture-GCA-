extends Node
## Tracks open-world region lifecycle and streaming-aware object invalidation.
##
## Records region membership, emits explicit lifecycle transitions, and marks
## canonical object handles unresolved after region unload completes.
class_name GameRegionStreamingService

## Emitted whenever a region enters a new [enum State].
signal region_state_changed(region_id: StringName, state: int)

enum State { UNLOADED, LOADING, INITIALIZING, ACTIVE, DORMANT, UNLOADING, FAILED }
enum OfflinePolicy { FREEZE_WHILE_UNLOADED, ADVANCE_ELAPSED_DURATION, RESOLVE_ON_LOAD, UNSUPPORTED }

# ======== EXPORT =========
@export var object_resolver: GameObjectResolver = null

# ======== PRIVATE VAR ======
var _regions: Dictionary = {}

# ====== PUBLIC ========
## Replaces a region's lifecycle state and registered object IDs.
func set_state(region_id: StringName, state: int, object_ids: Array[StringName] = []) -> void:
	_regions[region_id] = {"state": state, "object_ids": object_ids.duplicate()}
	region_state_changed.emit(region_id, state)

## Marks a valid region ID as loading.
func request_load(region_id: StringName) -> GameCommandResult:
	if region_id.is_empty():
		return GameCommandResult.configuration_error(&"invalid_region_id", "Region ID is required.")
	set_state(region_id, State.LOADING)
	return GameCommandResult.success_changed(&"region_load_requested")

## Marks a known region as unloading.
func request_unload(region_id: StringName) -> GameCommandResult:
	if not _regions.has(region_id):
		return GameCommandResult.rejected_permanent(&"unknown_region", "Region is unknown.")
	_regions[region_id].state = State.UNLOADING
	region_state_changed.emit(region_id, State.UNLOADING)
	return GameCommandResult.success_changed(&"region_unload_requested")

## Completes unload and marks all region object handles unresolved-known.
func complete_unload(region_id: StringName) -> GameCommandResult:
	if not _regions.has(region_id):
		return GameCommandResult.rejected_permanent(&"unknown_region", "Region is unknown.")
	if object_resolver != null:
		for object_id: StringName in _regions[region_id].object_ids:
			object_resolver.mark_unresolved(object_id)
	_regions[region_id].state = State.UNLOADED
	region_state_changed.emit(region_id, State.UNLOADED)
	return GameCommandResult.success_changed(&"region_unloaded")

## Returns a deep copy of all region states and object membership.
func get_debug_snapshot() -> Dictionary:
	return _regions.duplicate(true)
