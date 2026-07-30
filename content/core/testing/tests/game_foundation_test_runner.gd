extends Node
class_name GameFoundationTestRunner

# ======== PRIVATE VAR ======
var _passed: int = 0
var _failed: int = 0
var _failure_messages: Array[String] = []
var _cancelled_operation_executions: int = 0

# ======= OVERRIDE =======
func _ready() -> void:
	await get_tree().process_frame
	_run_all_tests()
	_print_summary()
	get_tree().quit(0 if _failed == 0 else 1)

# ====== HELPERS ========
func _assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		return
	_failed += 1
	_failure_messages.append(message)
	push_error("[GCA TEST] %s" % message)

func _make_identity(stable_id: StringName) -> GameObjectIdentity:
	var identity := GameObjectIdentity.new()
	identity.stable_id = stable_id
	return identity

func _make_basic_object(stable_id: StringName = &"test.object") -> Dictionary:
	var root := Node.new()
	root.name = "TestObject"
	add_child(root)
	var kernel := GameObjectKernel.new()
	kernel.name = "GameObjectKernel"
	kernel.auto_initialize = false
	root.add_child(kernel)
	var identity: GameObjectIdentity = _make_identity(stable_id)
	kernel.add_child(identity)
	var tags := GameTagContainer.new()
	kernel.add_child(tags)
	return {"root": root, "kernel": kernel, "identity": identity, "tags": tags}

func _get_kernel(object_data: Dictionary) -> GameObjectKernel:
	return object_data.get("kernel") as GameObjectKernel

func _get_tags(object_data: Dictionary) -> GameTagContainer:
	return object_data.get("tags") as GameTagContainer

func _free_object(object_data: Dictionary) -> void:
	var root: Node = object_data.get("root") as Node
	if root != null and is_instance_valid(root):
		root.queue_free()

func _dispatch_increment(kernel: GameObjectKernel, amount: int) -> GameCommandResult:
	var context: GameExecutionContext = kernel.create_root_execution_context(&"test.command", "increment")
	var command := GameCommand.new(
		GameTestCounterFeature.COMMAND_INCREMENT,
		kernel.get_object_handle(),
		kernel.get_object_handle(),
		context,
		amount,
		GameCapabilityIds.TEST_COUNTER
	)
	return kernel.dispatch_command(command)

func _complete_operation(_context: GameExecutionContext) -> GameCommandResult:
	return GameCommandResult.success_changed()

func _count_operation_execution(_context: GameExecutionContext) -> GameCommandResult:
	_cancelled_operation_executions += 1
	return GameCommandResult.success_changed()

func _test_positive_foundation_flow() -> void:
	var data: Dictionary = _make_basic_object(&"test.positive")
	var kernel: GameObjectKernel = _get_kernel(data)
	var counter := GameTestCounterFeature.new()
	counter.initial_value = 1
	kernel.add_child(counter)
	var threshold := GameTestThresholdFeature.new()
	threshold.threshold = 3
	kernel.add_child(threshold)
	var chain := GameTestChainFeature.new()
	kernel.add_child(chain)
	var multi_a := GameTestMultiProviderFeature.new()
	multi_a.feature_id = &"test.multi.a"
	kernel.add_child(multi_a)
	var multi_b := GameTestMultiProviderFeature.new()
	multi_b.feature_id = &"test.multi.b"
	kernel.add_child(multi_b)
	var recorder := GameTestEventRecorderFeature.new()
	kernel.add_child(recorder)

	var initialize_result: GameCommandResult = kernel.initialize_kernel()
	_assert_true(initialize_result.is_success(), "Kernel should initialize a valid object composition.")
	_assert_true(kernel.get_lifecycle_state() == GameObjectKernel.LifecycleState.ACTIVATED, "Kernel should reach Activated state.")
	_assert_true(threshold.get_cached_counter() == counter, "Required capability should be cached by the dependent feature.")
	_assert_true(kernel.get_capability_registry().get_all(GameCapabilityIds.TEST_MULTI).size() == 2, "Multi capability should resolve both providers.")

	var command_result: GameCommandResult = _dispatch_increment(kernel, 2)
	_assert_true(command_result.is_success() and counter.get_value() == 3, "Command should mutate mock state and return a structured success result.")
	_assert_true(threshold.get_reached_count() == 1, "Local event should reach the threshold feature through the kernel.")
	_assert_true(recorder.get_event_sequences().size() >= 2, "Recorder should receive deterministically sequenced local events.")

	var query := GameQuery.new(
		GameTestCounterFeature.QUERY_VALUE,
		kernel.get_object_handle(),
		kernel.get_object_handle(),
		GameCapabilityIds.TEST_COUNTER
	)
	var query_result: GameQueryResult = kernel.dispatch_query(query)
	_assert_true(query_result.is_found() and int(query_result.get_value()) == 3, "Query should read state without mutation.")

	var chain_context: GameExecutionContext = kernel.create_root_execution_context(&"test.chain", "chain")
	var chain_command := GameCommand.new(
		GameTestChainFeature.COMMAND_START,
		kernel.get_object_handle(),
		kernel.get_object_handle(),
		chain_context,
		3,
		GameCapabilityIds.TEST_CHAIN
	)
	var chain_result: GameCommandResult = kernel.dispatch_command(chain_command)
	_assert_true(chain_result.is_success(), "Chain command should enqueue the root operation.")
	kernel.process_execution_queue()
	var contexts: Array[Dictionary] = chain.get_executed_contexts()
	_assert_true(contexts.size() == 3, "Execution queue should process all queued chain operations.")
	_assert_true(int(contexts[1]["parent_operation_id"]) == int(contexts[0]["operation_id"]), "Child execution context should reference its parent operation.")
	_assert_true(int(contexts[2]["root_operation_id"]) == int(contexts[0]["root_operation_id"]), "Child execution context should preserve root operation ID.")

	var tags: GameTagContainer = _get_tags(data)
	var source_a: GameTagSourceHandle = tags.add_tag(GameTagIds.STATUS_BURNING, &"source.a")
	var source_b: GameTagSourceHandle = tags.add_tag(GameTagIds.STATUS_BURNING, &"source.b")
	_assert_true(tags.has_exact_tag(GameTagIds.STATUS_BURNING), "Tag should be present after two sources grant it.")
	tags.remove_tag(source_a)
	_assert_true(tags.has_exact_tag(GameTagIds.STATUS_BURNING), "Removing one source must not remove a tag owned by another source.")
	tags.remove_tag(source_b)
	_assert_true(not tags.has_exact_tag(GameTagIds.STATUS_BURNING), "Tag should disappear after its last source is removed.")

	var handle: GameObjectHandle = kernel.get_object_handle()
	kernel.shutdown_kernel()
	_assert_true(not handle.is_resolved() and handle.is_invalidated(), "Object handle should invalidate during kernel shutdown.")
	_free_object(data)

func _test_deactivation_query_and_reactivation() -> void:
	var data: Dictionary = _make_basic_object(&"test.deactivation")
	var counter := GameTestCounterFeature.new()
	counter.initial_value = 5
	_get_kernel(data).add_child(counter)
	var initialize_result: GameCommandResult = _get_kernel(data).initialize_kernel()
	_assert_true(initialize_result.is_success(), "Deactivation fixture should initialize.")
	_get_kernel(data).deactivate_kernel(&"test_pause")

	var query := GameQuery.new(
		GameTestCounterFeature.QUERY_VALUE,
		_get_kernel(data).get_object_handle(),
		_get_kernel(data).get_object_handle(),
		GameCapabilityIds.TEST_COUNTER
	)
	var query_result: GameQueryResult = _get_kernel(data).dispatch_query(query)
	_assert_true(query_result.is_found() and int(query_result.get_value()) == 5, "Queries should remain available while a feature is deactivated.")

	var command_result: GameCommandResult = _dispatch_increment(_get_kernel(data), 1)
	_assert_true(command_result.get_status() == GameCommandResult.Status.REJECTED_TEMPORARY and counter.get_value() == 5, "Commands should be rejected while the target kernel is deactivated.")
	var reactivate_result: GameCommandResult = _get_kernel(data).reactivate_kernel()
	_assert_true(reactivate_result.is_success(), "Kernel should reactivate features that support reactivation.")
	_assert_true(_dispatch_increment(_get_kernel(data), 1).is_success() and counter.get_value() == 6, "Command routing should resume after reactivation.")
	_get_kernel(data).shutdown_kernel()
	_free_object(data)

func _test_missing_required_capability() -> void:
	var data: Dictionary = _make_basic_object(&"test.missing_cap")
	var threshold := GameTestThresholdFeature.new()
	_get_kernel(data).add_child(threshold)
	var result: GameCommandResult = _get_kernel(data).initialize_kernel()
	_assert_true(result.is_configuration_error(), "Missing required capability should block kernel activation.")
	_free_object(data)

func _test_duplicate_exclusive_capability() -> void:
	var data: Dictionary = _make_basic_object(&"test.duplicate_exclusive")
	var counter_a := GameTestCounterFeature.new()
	counter_a.feature_id = &"test.counter.a"
	_get_kernel(data).add_child(counter_a)
	var counter_b := GameTestCounterFeature.new()
	counter_b.feature_id = &"test.counter.b"
	_get_kernel(data).add_child(counter_b)
	var result: GameCommandResult = _get_kernel(data).initialize_kernel()
	_assert_true(result.is_configuration_error(), "Two providers of an exclusive capability should fail validation.")
	_free_object(data)


func _test_dependency_cycle() -> void:
	var data: Dictionary = _make_basic_object(&"test.dependency_cycle")
	var feature_a := GameTestConfigurableFeature.new()
	feature_a.configure(&"test.cycle.a", &"test.cycle.capability_a", &"test.cycle.capability_b")
	_get_kernel(data).add_child(feature_a)
	var feature_b := GameTestConfigurableFeature.new()
	feature_b.configure(&"test.cycle.b", &"test.cycle.capability_b", &"test.cycle.capability_a")
	_get_kernel(data).add_child(feature_b)
	var result: GameCommandResult = _get_kernel(data).initialize_kernel()
	_assert_true(result.is_configuration_error(), "Dependency cycle should block kernel activation.")
	_free_object(data)

func _test_duplicate_feature_id() -> void:
	var data: Dictionary = _make_basic_object(&"test.duplicate_feature")
	var first := GameTestEventRecorderFeature.new()
	first.feature_id = &"duplicate"
	_get_kernel(data).add_child(first)
	var second := GameTestEventRemovalFeature.new()
	second.feature_id = &"duplicate"
	_get_kernel(data).add_child(second)
	var result: GameCommandResult = _get_kernel(data).initialize_kernel()
	_assert_true(result.is_configuration_error(), "Duplicate feature_id should fail validation.")
	_free_object(data)

func _test_duplicate_feature_type() -> void:
	var data: Dictionary = _make_basic_object(&"test.duplicate_type")
	var first := GameTestEventRecorderFeature.new()
	first.feature_id = &"test.recorder.a"
	_get_kernel(data).add_child(first)
	var second := GameTestEventRecorderFeature.new()
	second.feature_id = &"test.recorder.b"
	_get_kernel(data).add_child(second)
	var result: GameCommandResult = _get_kernel(data).initialize_kernel()
	_assert_true(result.is_configuration_error(), "Duplicate feature type should require explicit multi-instance support.")
	_free_object(data)

func _test_operation_budget_and_cycle_guard() -> void:
	var data: Dictionary = _make_basic_object(&"test.queue_limits")
	_get_kernel(data).max_operations_per_root = 2
	_get_kernel(data).max_repeats_per_guard = 1
	var result: GameCommandResult = _get_kernel(data).initialize_kernel()
	_assert_true(result.is_success(), "Queue limit fixture should initialize.")
	var root_context: GameExecutionContext = _get_kernel(data).create_root_execution_context(&"test.queue", "limits")
	var operation_a := GameCallbackOperation.new(&"same", root_context, _complete_operation, &"source", _get_kernel(data).get_object_handle(), &"guard")
	var cycle_result_a: GameCommandResult = _get_kernel(data).get_object_context().enqueue_operation(operation_a)
	var operation_b := GameCallbackOperation.new(&"same", root_context, _complete_operation, &"source", _get_kernel(data).get_object_handle(), &"guard")
	var cycle_result_b: GameCommandResult = _get_kernel(data).get_object_context().enqueue_operation(operation_b)
	_assert_true(cycle_result_a.is_success() and cycle_result_b.get_status() == GameCommandResult.Status.CYCLE_GUARD, "Cycle guard should reject repeated guard keys within one root chain.")

	var distinct_context: GameExecutionContext = _get_kernel(data).create_root_execution_context(&"test.queue", "budget")
	var budget_a := GameCallbackOperation.new(&"a", distinct_context, _complete_operation, &"source", _get_kernel(data).get_object_handle(), &"a")
	var budget_b := GameCallbackOperation.new(&"b", distinct_context, _complete_operation, &"source", _get_kernel(data).get_object_handle(), &"b")
	var budget_c := GameCallbackOperation.new(&"c", distinct_context, _complete_operation, &"source", _get_kernel(data).get_object_handle(), &"c")
	_get_kernel(data).get_object_context().enqueue_operation(budget_a)
	_get_kernel(data).get_object_context().enqueue_operation(budget_b)
	var budget_result: GameCommandResult = _get_kernel(data).get_object_context().enqueue_operation(budget_c)
	_assert_true(budget_result.get_status() == GameCommandResult.Status.QUEUE_LIMIT, "Operation budget should reject excess operations in a root chain.")
	_get_kernel(data).shutdown_kernel()
	_free_object(data)

func _test_root_operation_cancellation() -> void:
	var data: Dictionary = _make_basic_object(&"test.root_cancel")
	var initialize_result: GameCommandResult = _get_kernel(data).initialize_kernel()
	_assert_true(initialize_result.is_success(), "Root cancellation fixture should initialize.")
	_cancelled_operation_executions = 0
	var context: GameExecutionContext = _get_kernel(data).create_root_execution_context(&"test.cancel", "root_cancel")
	var first := GameCallbackOperation.new(&"test.cancel.first", context, _count_operation_execution, &"test", _get_kernel(data).get_object_handle(), &"first")
	var second := GameCallbackOperation.new(&"test.cancel.second", context, _count_operation_execution, &"test", _get_kernel(data).get_object_handle(), &"second")
	_get_kernel(data).get_object_context().enqueue_operation(first)
	_get_kernel(data).get_object_context().enqueue_operation(second)
	_get_kernel(data).get_object_context().cancel_root_operations(context.get_root_operation_id(), &"test_cancelled")
	var processed: int = _get_kernel(data).process_execution_queue()
	_assert_true(processed == 0 and _cancelled_operation_executions == 0, "Cancelling a root should remove its pending operations before execution.")
	var stale_operation := GameCallbackOperation.new(&"test.cancel.stale", context, _count_operation_execution, &"test", _get_kernel(data).get_object_handle(), &"stale")
	var stale_result: GameCommandResult = _get_kernel(data).get_object_context().enqueue_operation(stale_operation)
	_assert_true(stale_result.get_status() == GameCommandResult.Status.CANCELLED, "A stale cancelled root context should not enqueue new operations.")
	_get_kernel(data).shutdown_kernel()
	_free_object(data)

func _test_invalid_target() -> void:
	var data: Dictionary = _make_basic_object(&"test.invalid_target")
	var counter := GameTestCounterFeature.new()
	_get_kernel(data).add_child(counter)
	var result: GameCommandResult = _get_kernel(data).initialize_kernel()
	_assert_true(result.is_success(), "Invalid-target fixture should initialize.")
	var invalid_handle := GameObjectHandle.new(&"gone", 42)
	invalid_handle.invalidate()
	var command := GameCommand.new(GameTestCounterFeature.COMMAND_INCREMENT, _get_kernel(data).get_object_handle(), invalid_handle, null, 1, GameCapabilityIds.TEST_COUNTER)
	var command_result: GameCommandResult = _get_kernel(data).dispatch_command(command)
	_assert_true(command_result.get_status() == GameCommandResult.Status.INVALID_TARGET, "Command sent to an invalidated handle should return invalid target.")
	_get_kernel(data).shutdown_kernel()
	_free_object(data)

func _test_runtime_removal_during_event() -> void:
	var data: Dictionary = _make_basic_object(&"test.runtime_removal")
	var counter := GameTestCounterFeature.new()
	_get_kernel(data).add_child(counter)
	var removal := GameTestEventRemovalFeature.new()
	_get_kernel(data).add_child(removal)
	var recorder := GameTestEventRecorderFeature.new()
	_get_kernel(data).add_child(recorder)
	var result: GameCommandResult = _get_kernel(data).initialize_kernel()
	_assert_true(result.is_success(), "Runtime removal fixture should initialize.")
	_dispatch_increment(_get_kernel(data), 1)
	_assert_true(removal.was_removal_requested(), "Feature should request removal while an event is being delivered.")
	_assert_true(_get_kernel(data).get_feature(removal.feature_id) == null, "Feature removal should be deferred until event delivery is safe.")
	_assert_true(recorder.get_event_types().has(GameTestCounterFeature.EVENT_CHANGED), "Other listeners should still receive the event during deferred removal.")
	_get_kernel(data).shutdown_kernel()
	_free_object(data)

func _test_infrastructure_feature_immutability() -> void:
	var data: Dictionary = _make_basic_object(&"test.infrastructure_immutable")
	var initialize_result: GameCommandResult = _get_kernel(data).initialize_kernel()
	_assert_true(initialize_result.is_success(), "Infrastructure immutability fixture should initialize.")
	var remove_result: GameCommandResult = _get_kernel(data).remove_runtime_feature(_get_tags(data))
	_assert_true(remove_result.is_configuration_error(), "Runtime removal of the primary tag container should be rejected.")
	_assert_true(_get_kernel(data).get_capability_registry().has_capability(GameCapabilityIds.TAGS_QUERY), "Rejected infrastructure removal must preserve registered capabilities.")
	_get_kernel(data).shutdown_kernel()
	_free_object(data)

func _test_lazy_dependency_resolution() -> void:
	var data: Dictionary = _make_basic_object(&"test.lazy_dependency")
	var dependent := GameTestConfigurableFeature.new()
	dependent.configure(&"test.lazy.dependent", &"", &"test.lazy.provider")
	dependent.allow_multiple_instances = true
	dependent.required_dependencies[0].lazy_resolution = true
	_get_kernel(data).add_child(dependent)

	var initialize_result: GameCommandResult = _get_kernel(data).initialize_kernel()
	_assert_true(initialize_result.is_success(), "Explicit lazy dependency should not block initial activation.")
	_assert_true(not dependent.has_cached_dependency(&"test.lazy.provider"), "Missing lazy dependency should not create a cache entry.")

	var provider := GameTestConfigurableFeature.new()
	provider.configure(&"test.lazy.provider_feature", &"test.lazy.provider")
	provider.allow_multiple_instances = true
	_get_kernel(data).add_child(provider)
	var register_result: GameCommandResult = _get_kernel(data).register_runtime_feature(provider)
	_assert_true(register_result.is_success(), "Lazy dependency provider should register at runtime.")
	_assert_true(dependent.get_dependency(&"test.lazy.provider") == provider, "Lazy dependency should resolve and cache after its provider appears.")
	_get_kernel(data).shutdown_kernel()
	_free_object(data)

func _test_dynamic_registration_and_loss() -> void:
	var data: Dictionary = _make_basic_object(&"test.dynamic")
	var counter := GameTestCounterFeature.new()
	_get_kernel(data).add_child(counter)
	var result: GameCommandResult = _get_kernel(data).initialize_kernel()
	_assert_true(result.is_success(), "Dynamic registration fixture should initialize.")
	var threshold := GameTestThresholdFeature.new()
	threshold.feature_id = &"test.threshold.runtime"
	_get_kernel(data).add_child(threshold)
	var register_result: GameCommandResult = _get_kernel(data).register_runtime_feature(threshold)
	_assert_true(register_result.is_success() and threshold.get_cached_counter() == counter, "Runtime feature should resolve and cache dependencies atomically.")
	var remove_result: GameCommandResult = _get_kernel(data).remove_runtime_feature(counter)
	_assert_true(remove_result.is_success(), "Runtime capability provider should be removable through the kernel.")
	_assert_true(threshold.get_lifecycle_state() != GameFeature.LifecycleState.ACTIVATED, "Dependent feature should deactivate after a required capability is lost.")
	_get_kernel(data).shutdown_kernel()
	_free_object(data)

func _run_all_tests() -> void:
	_test_positive_foundation_flow()
	_test_deactivation_query_and_reactivation()
	_test_missing_required_capability()
	_test_duplicate_exclusive_capability()
	_test_dependency_cycle()
	_test_duplicate_feature_id()
	_test_duplicate_feature_type()
	_test_operation_budget_and_cycle_guard()
	_test_root_operation_cancellation()
	_test_invalid_target()
	_test_runtime_removal_during_event()
	_test_infrastructure_feature_immutability()
	_test_lazy_dependency_resolution()
	_test_dynamic_registration_and_loss()

func _print_summary() -> void:
	print("============================================================")
	print("GCA Stage 1 Foundation tests: %s passed, %s failed" % [_passed, _failed])
	for message: String in _failure_messages:
		print("FAILED: %s" % message)
	print("============================================================")
