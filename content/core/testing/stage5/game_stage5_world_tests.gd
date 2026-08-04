extends RefCounted
class_name GameStage5WorldTests

# ====== PUBLIC ========
static func test_handle_states() -> void:
	var handle := GameObjectHandle.new(&"test.object")
	handle.mark_unresolved_known()
	assert(handle.is_known())
	assert(not handle.is_resolved())
	handle.mark_loading_requested()
	assert(handle.get_state() == GameObjectHandle.State.LOADING_REQUESTED)

static func test_canonical_resolver_handle() -> void:
	var resolver := GameObjectResolver.new()
	var handle: GameObjectHandle = resolver.register_known(&"test.object")
	assert(handle == resolver.resolve(&"test.object"))

static func test_persistence_migration_failure() -> void:
	var coordinator := GamePersistenceCoordinator.new()
	var participant := GamePersistenceParticipant.new()
	participant.object_id = &"test.object"
	participant.component_id = &"test.component"
	participant.schema_version = 2
	participant.capture_callback = func() -> Dictionary: return {"value": 1}
	participant.restore_callback = func(_data: Dictionary) -> GameCommandResult: return GameCommandResult.success_changed(&"restored")
	coordinator.register_participant(participant)
	var report: Dictionary = coordinator.restore_world_snapshot({"objects": [{"stable_id": &"test.object", "components": {&"test.component": {"schema_version": 1, "data": {"value": 1}}}}]})
	assert(report.migration_failures.size() == 1)

static func test_targeting_order() -> void:
	var resolver := GameObjectResolver.new()
	var targeting := GameTargetingService.new()
	targeting.object_resolver = resolver
	var result: Dictionary = targeting.query_sphere(Vector3.ZERO, 10.0)
	assert(result.query_version == 1)
	assert((result.handles as Array).is_empty())

static func run_all() -> void:
	test_handle_states()
	test_canonical_resolver_handle()
	test_persistence_migration_failure()
	test_targeting_order()
