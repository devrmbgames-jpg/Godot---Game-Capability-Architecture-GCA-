extends Node
## Coordinates world-object registration, snapshot capture, migration, and restore phases.
##
## Persists stable object metadata and delegates component state to registered
## [GamePersistenceParticipant] contracts in a deterministic phased restore flow.
class_name GamePersistenceCoordinator

## Emitted whenever the coordinator enters a new [enum RestorePhase].
signal restore_phase_changed(phase: int)
## Emitted after all restore phases complete with a structured report.
signal world_restored(report: Dictionary)

enum RestorePhase { IDLE, VALIDATE_AND_MIGRATE, RESTORE_LOCAL_STATE, RESOLVE_REFERENCES, ACTIVATE_GAMEPLAY, COMPLETED }

# ======== EXPORT =========
@export var object_resolver: GameObjectResolver = null

# ======== PRIVATE VAR ======
var _participants: Dictionary = {}
var _objects: Dictionary = {}
var _phase: int = RestorePhase.IDLE

# ====== HELPERS ========
func _key(object_id: StringName, component_id: StringName) -> String:
	return "%s::%s" % [object_id, component_id]

func _set_phase(value: int) -> void:
	_phase = value
	restore_phase_changed.emit(value)

# ====== PUBLIC ========
## Registers stable object metadata for future world snapshots.
func register_object(handle: GameObjectHandle, scene_id: StringName = &"", region_id: StringName = &"", lifecycle: StringName = &"active") -> GameCommandResult:
	if handle == null or handle.get_stable_id().is_empty():
		return GameCommandResult.configuration_error(&"invalid_persistent_object", "Stable handle required.")
	_objects[handle.get_stable_id()] = {"handle": handle, "scene_id": scene_id, "region_id": region_id, "lifecycle": lifecycle}
	return GameCommandResult.success_changed(&"persistent_object_registered")

## Registers one unique object/component persistence participant.
func register_participant(participant: GamePersistenceParticipant) -> GameCommandResult:
	if participant == null or not participant.is_valid():
		return GameCommandResult.configuration_error(&"invalid_persistence_participant", "Participant is incomplete.")
	var key: String = _key(participant.object_id, participant.component_id)
	if _participants.has(key):
		return GameCommandResult.configuration_error(&"duplicate_persistence_component", "Duplicate component ID.")
	_participants[key] = participant
	return GameCommandResult.success_changed(&"participant_registered")

## Captures a deterministic world snapshot containing object metadata and component data.
func capture_world_snapshot() -> Dictionary:
	var objects: Array[Dictionary] = []
	var ids: Array = _objects.keys()
	ids.sort()
	for object_id: StringName in ids:
		var meta: Dictionary = _objects[object_id]
		var components: Dictionary = {}
		var handle: GameObjectHandle = meta.handle
		var transform: Transform3D = Transform3D.IDENTITY
		if handle != null and handle.get_root() is Node3D:
			transform = (handle.get_root() as Node3D).global_transform
		for participant: GamePersistenceParticipant in _participants.values():
			if participant.object_id == object_id:
				components[participant.component_id] = {"schema_version": participant.schema_version, "data": participant.capture_snapshot()}
		objects.append({"stable_id": object_id, "scene_id": meta.scene_id, "region_id": meta.region_id, "lifecycle": meta.lifecycle, "transform": transform, "components": components})
	return {"schema_version": 1, "objects": objects}

## Validates, migrates, restores, and post-resolves all known component snapshots.
## Returns a report listing restored, missing, migration-failed, and restore-failed entries.
func restore_world_snapshot(snapshot: Dictionary) -> Dictionary:
	var report: Dictionary = {"restored": [], "missing": [], "migration_failures": [], "restore_failures": []}
	var prepared: Array[Dictionary] = []
	_set_phase(RestorePhase.VALIDATE_AND_MIGRATE)
	for object_data: Dictionary in snapshot.get("objects", []):
		for component_id: StringName in (object_data.get("components", {}) as Dictionary).keys():
			var participant: GamePersistenceParticipant = _participants.get(_key(object_data.stable_id, component_id)) as GamePersistenceParticipant
			if participant == null:
				report.missing.append({"object_id": object_data.stable_id, "component_id": component_id})
				continue
			var entry: Dictionary = object_data.components[component_id]
			var data: Dictionary = participant.migrate_snapshot(entry.data, int(entry.schema_version))
			if data.is_empty() and int(entry.schema_version) != participant.schema_version:
				report.migration_failures.append({"object_id": object_data.stable_id, "component_id": component_id})
				continue
			prepared.append({"participant": participant, "object_id": object_data.stable_id, "component_id": component_id, "data": data})
	_set_phase(RestorePhase.RESTORE_LOCAL_STATE)
	for record: Dictionary in prepared:
		var result: GameCommandResult = record.participant.restore_snapshot(record.data)
		if result.is_success():
			report.restored.append({"object_id": record.object_id, "component_id": record.component_id})
		else:
			report.restore_failures.append({"object_id": record.object_id, "component_id": record.component_id, "reason": result.get_reason_code()})
	_set_phase(RestorePhase.RESOLVE_REFERENCES)
	for record: Dictionary in prepared:
		var post_result: GameCommandResult = record.participant.post_restore(object_resolver)
		if not post_result.is_success():
			report.restore_failures.append({"object_id": record.object_id, "component_id": record.component_id, "reason": post_result.get_reason_code()})
	_set_phase(RestorePhase.ACTIVATE_GAMEPLAY)
	_set_phase(RestorePhase.COMPLETED)
	world_restored.emit(report)
	return report

## Returns registered object IDs, participant count, and current restore phase.
func get_debug_snapshot() -> Dictionary:
	return {"objects": _objects.keys(), "participant_count": _participants.size(), "restore_phase": _phase}
