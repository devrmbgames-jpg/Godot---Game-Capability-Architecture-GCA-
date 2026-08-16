extends Node
class_name GameEffectTypedSpecTestRunner

# ======== PRIVATE VAR ======
var _passed: int = 0
var _failed: int = 0
var _failure_messages: Array[String] = []

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
	push_error("[GCA EFFECT TEST] %s" % message)

func _assert_float(actual: float, expected: float, message: String) -> void:
	_assert_true(is_equal_approx(actual, expected), "%s Expected %s, got %s." % [message, expected, actual])

func _make_attribute_spec(attribute_id: StringName, magnitude: float, priority: int = 0) -> GameEffectAttributeModifierSpec:
	var spec := GameEffectAttributeModifierSpec.new()
	spec.attribute_id = attribute_id
	spec.operation = GameAttributeModifier.Operation.ADD
	spec.magnitude = magnitude
	spec.priority = priority
	return spec

func _make_meter_spec(meter_id: StringName, delta: float) -> GameEffectMeterOperationSpec:
	var spec := GameEffectMeterOperationSpec.new()
	spec.meter_id = meter_id
	spec.delta = delta
	return spec

func _make_effect(effect_id: StringName, duration_policy: GameEffectDefinition.DurationPolicy = GameEffectDefinition.DurationPolicy.INFINITE) -> GameEffectDefinition:
	var definition := GameEffectDefinition.new()
	definition.effect_id = effect_id
	definition.duration_policy = duration_policy
	return definition

func _make_runtime_fixture() -> Dictionary:
	var root := Node.new()
	root.name = "EffectTypedSpecFixture"
	add_child(root)

	var kernel := GameObjectKernel.new()
	kernel.name = "GameObjectKernel"
	kernel.auto_initialize = false
	root.add_child(kernel)

	var identity := GameObjectIdentity.new()
	identity.stable_id = &"test.effect.fixture"
	kernel.add_child(identity)
	kernel.add_child(GameTagContainer.new())

	var attribute_definition := GameAttributeDefinition.new()
	attribute_definition.attribute_id = &"test.attribute.power"
	attribute_definition.default_base = 10.0
	var attributes := GameAttributes.new()
	attributes.definitions.append(attribute_definition)
	kernel.add_child(attributes)

	var meter_definition := GameMeterDefinition.new()
	meter_definition.meter_id = &"test.meter.health"
	meter_definition.constant_maximum = 100.0
	meter_definition.initial_policy = GameMeterDefinition.InitialPolicy.FULL
	var meters := GameMeters.new()
	meters.definitions.append(meter_definition)
	kernel.add_child(meters)

	var effects := GameEffects.new()
	kernel.add_child(effects)

	var initialize_result: GameCommandResult = kernel.initialize_kernel()
	return {
		"root": root,
		"kernel": kernel,
		"attributes": attributes,
		"meters": meters,
		"effects": effects,
		"initialize_result": initialize_result,
	}

func _free_fixture(fixture: Dictionary) -> void:
	var kernel: GameObjectKernel = fixture.get("kernel") as GameObjectKernel
	if kernel != null:
		kernel.shutdown_kernel()
	var root: Node = fixture.get("root") as Node
	if root != null and is_instance_valid(root):
		root.queue_free()

func _fixture_initialized(fixture: Dictionary, message: String) -> bool:
	var result: GameCommandResult = fixture.get("initialize_result") as GameCommandResult
	var initialized: bool = result != null and result.is_success()
	_assert_true(initialized, message)
	return initialized

func _make_context(fixture: Dictionary, operation_id: StringName) -> GameExecutionContext:
	var kernel: GameObjectKernel = fixture.get("kernel") as GameObjectKernel
	return kernel.create_root_execution_context(operation_id, String(operation_id))

func _apply_to_fixture(fixture: Dictionary, definition: GameEffectDefinition, operation_id: StringName) -> GameCommandResult:
	var kernel: GameObjectKernel = fixture.get("kernel") as GameObjectKernel
	var effects: GameEffects = fixture.get("effects") as GameEffects
	return effects.apply_effect(
		definition,
		kernel.get_object_handle(),
		kernel.get_object_handle(),
		_make_context(fixture, operation_id)
	)

func _get_first_effect_handle(effects: GameEffects) -> int:
	var snapshot: Array[Dictionary] = effects.get_debug_snapshot()
	if snapshot.is_empty():
		return 0
	return int(snapshot[0].get("handle_id", 0))

func _test_spec_validation() -> void:
	var attribute_spec: GameEffectAttributeModifierSpec = _make_attribute_spec(&"test.attribute.power", 2.0, 7)
	_assert_true(attribute_spec.is_valid(), "Valid attribute modifier spec should pass validation.")
	attribute_spec.attribute_id = &""
	_assert_true(not attribute_spec.is_valid(), "Empty attribute_id should fail attribute spec validation.")
	attribute_spec.attribute_id = &"test.attribute.power"
	attribute_spec.magnitude = INF
	_assert_true(not attribute_spec.is_valid(), "Infinite attribute magnitude should fail validation.")
	attribute_spec.magnitude = 1.0
	attribute_spec.set(&"operation", 999)
	_assert_true(not attribute_spec.is_valid(), "Unknown attribute operation enum should fail validation.")

	var meter_spec: GameEffectMeterOperationSpec = _make_meter_spec(&"test.meter.health", -5.0)
	_assert_true(meter_spec.is_valid(), "Valid meter operation spec should pass validation.")
	meter_spec.meter_id = &""
	_assert_true(not meter_spec.is_valid(), "Empty meter_id should fail meter spec validation.")
	meter_spec.meter_id = &"test.meter.health"
	meter_spec.delta = NAN
	_assert_true(not meter_spec.is_valid(), "NaN meter delta should fail validation.")

func _test_definition_nested_validation() -> void:
	var definition: GameEffectDefinition = _make_effect(&"test.effect.invalid_nested")
	definition.attribute_modifiers.append(null)
	var errors: PackedStringArray = definition.get_validation_errors()
	_assert_true(not definition.is_valid(), "Definition should reject a null nested attribute spec.")
	_assert_true(not errors.is_empty() and errors[0].contains("attribute modifier"), "Nested validation should identify the failing effect collection.")

func _test_legacy_migration() -> void:
	var attribute_report: Dictionary = GameEffectLegacyMigrator.migrate_attribute_modifier({
		&"attribute_id": &"test.attribute.power",
		&"magnitude": 3.5,
	})
	var attribute_spec: GameEffectAttributeModifierSpec = attribute_report.get("spec") as GameEffectAttributeModifierSpec
	_assert_true(bool(attribute_report.get("ok", false)), "Legacy attribute modifier using historical defaults should migrate.")
	_assert_true(attribute_spec != null and attribute_spec.operation == GameAttributeModifier.Operation.ADD, "Missing legacy operation should materialize ADD.")
	_assert_float(attribute_spec.magnitude, 3.5, "Legacy magnitude should be preserved.")
	_assert_true(attribute_spec.priority == 0, "Missing legacy priority should materialize 0.")

	var meter_report: Dictionary = GameEffectLegacyMigrator.migrate_meter_operation({
		&"meter_id": &"test.meter.health",
		&"delta": -8,
	})
	var meter_spec: GameEffectMeterOperationSpec = meter_report.get("spec") as GameEffectMeterOperationSpec
	_assert_true(bool(meter_report.get("ok", false)), "Legacy meter operation should migrate.")
	_assert_float(meter_spec.delta, -8.0, "Legacy integer meter delta should preserve numeric semantics.")

	var unknown_key_report: Dictionary = GameEffectLegacyMigrator.migrate_meter_operation({
		&"meter_id": &"test.meter.health",
		&"delta": -1.0,
		&"legacy_extra": 42,
	})
	_assert_true(not bool(unknown_key_report.get("ok", true)), "Unknown legacy keys must stop successful migration.")

	var empty_target_report: Dictionary = GameEffectLegacyMigrator.migrate_attribute_modifier({})
	_assert_true(not bool(empty_target_report.get("ok", true)), "Historical empty target fallback should materialize and then fail typed validation.")

	var batch_report: Dictionary = GameEffectLegacyMigrator.migrate_operation_arrays(
		[
			{&"attribute_id": &"test.attribute.power", &"magnitude": 1.0},
			{&"attribute_id": &"test.attribute.power", &"operation": GameAttributeModifier.Operation.INCREASE, &"magnitude": 0.25, &"priority": 5},
		],
		[
			{&"meter_id": &"test.meter.health", &"delta": -2.0},
			{&"meter_id": &"test.meter.health", &"delta": -3.0},
		]
	)
	_assert_true(bool(batch_report.get("ok", false)), "Multiple legacy operations should migrate in one deterministic batch.")
	var migrated_attributes: Array = batch_report.get("attribute_modifiers") as Array
	var migrated_meters: Array = batch_report.get("meter_operations") as Array
	_assert_true(migrated_attributes.size() == 2 and migrated_meters.size() == 2, "Batch migration should preserve operation counts.")

func _test_runtime_application_and_cleanup() -> void:
	var fixture: Dictionary = _make_runtime_fixture()
	if not _fixture_initialized(fixture, "Typed effect runtime fixture should initialize."):
		_free_fixture(fixture)
		return
	var definition: GameEffectDefinition = _make_effect(&"test.effect.runtime")
	definition.attribute_modifiers.append(_make_attribute_spec(&"test.attribute.power", 2.0, 11))
	definition.meter_operations.append(_make_meter_spec(&"test.meter.health", -5.0))
	var result: GameCommandResult = _apply_to_fixture(fixture, definition, &"test.effect.runtime.apply")
	var attributes: GameAttributes = fixture.get("attributes") as GameAttributes
	var meters: GameMeters = fixture.get("meters") as GameMeters
	var effects: GameEffects = fixture.get("effects") as GameEffects
	_assert_true(result.is_success(), "Typed effect should apply successfully.")
	_assert_float(attributes.get_value(&"test.attribute.power"), 12.0, "Typed attribute modifier target, operation, and magnitude should reach Attributes.")
	_assert_float(meters.get_current(&"test.meter.health"), 95.0, "Typed meter delta should reach Meters.")
	var handle_id: int = _get_first_effect_handle(effects)
	_assert_true(handle_id > 0 and effects.remove_effect(handle_id, &"test_cleanup"), "Duration-independent active effect should expose a removable runtime handle.")
	_assert_float(attributes.get_value(&"test.attribute.power"), 10.0, "Removing the effect should clean up its owned attribute modifier.")
	_assert_float(meters.get_current(&"test.meter.health"), 95.0, "Removing the effect should not reverse already executed meter operations.")
	_free_fixture(fixture)

func _test_attribute_atomicity() -> void:
	var fixture: Dictionary = _make_runtime_fixture()
	if not _fixture_initialized(fixture, "Attribute atomicity fixture should initialize."):
		_free_fixture(fixture)
		return
	var definition: GameEffectDefinition = _make_effect(&"test.effect.attribute_atomicity")
	definition.attribute_modifiers.append(_make_attribute_spec(&"test.attribute.power", 4.0))
	definition.attribute_modifiers.append(_make_attribute_spec(&"test.attribute.missing", 2.0))
	var result: GameCommandResult = _apply_to_fixture(fixture, definition, &"test.effect.attribute_atomicity.apply")
	var attributes: GameAttributes = fixture.get("attributes") as GameAttributes
	var effects: GameEffects = fixture.get("effects") as GameEffects
	_assert_true(not result.is_success(), "Unknown second attribute target should reject effect configuration.")
	_assert_float(attributes.get_value(&"test.attribute.power"), 10.0, "Failed modifier batch must roll back the first modifier inside the transaction.")
	_assert_true(effects.get_debug_snapshot().is_empty(), "Failed modifier batch must not leave an active effect.")
	_free_fixture(fixture)

func _test_meter_failure_cleans_modifier() -> void:
	var fixture: Dictionary = _make_runtime_fixture()
	if not _fixture_initialized(fixture, "Meter failure cleanup fixture should initialize."):
		_free_fixture(fixture)
		return
	var definition: GameEffectDefinition = _make_effect(&"test.effect.meter_failure")
	definition.attribute_modifiers.append(_make_attribute_spec(&"test.attribute.power", 6.0))
	definition.meter_operations.append(_make_meter_spec(&"test.meter.missing", -1.0))
	var result: GameCommandResult = _apply_to_fixture(fixture, definition, &"test.effect.meter_failure.apply")
	var attributes: GameAttributes = fixture.get("attributes") as GameAttributes
	var effects: GameEffects = fixture.get("effects") as GameEffects
	_assert_true(not result.is_success(), "Unknown meter target should reject effect application.")
	_assert_float(attributes.get_value(&"test.attribute.power"), 10.0, "Meter failure must clean modifiers already owned by the effect.")
	_assert_true(effects.get_debug_snapshot().is_empty(), "Meter failure must not leave an active effect.")
	_free_fixture(fixture)

func _test_instant_cleanup() -> void:
	var fixture: Dictionary = _make_runtime_fixture()
	if not _fixture_initialized(fixture, "Instant cleanup fixture should initialize."):
		_free_fixture(fixture)
		return
	var definition: GameEffectDefinition = _make_effect(&"test.effect.instant", GameEffectDefinition.DurationPolicy.INSTANT)
	definition.attribute_modifiers.append(_make_attribute_spec(&"test.attribute.power", 5.0))
	var result: GameCommandResult = _apply_to_fixture(fixture, definition, &"test.effect.instant.apply")
	var attributes: GameAttributes = fixture.get("attributes") as GameAttributes
	var effects: GameEffects = fixture.get("effects") as GameEffects
	_assert_true(result.is_success(), "Instant typed effect should execute successfully.")
	_assert_float(attributes.get_value(&"test.attribute.power"), 10.0, "Instant effect should release its temporary modifier handle before returning.")
	_assert_true(effects.get_debug_snapshot().is_empty(), "Instant effect should not remain active.")
	_free_fixture(fixture)

func _test_periodic_stack_scaling() -> void:
	var fixture: Dictionary = _make_runtime_fixture()
	if not _fixture_initialized(fixture, "Periodic stack fixture should initialize."):
		_free_fixture(fixture)
		return
	var definition: GameEffectDefinition = _make_effect(&"test.effect.periodic_stack", GameEffectDefinition.DurationPolicy.DURATION)
	definition.duration = 5.0
	definition.period = 1.0
	definition.execute_period_on_apply = false
	definition.stacking_policy = GameEffectDefinition.StackingPolicy.ADD_STACK
	definition.stack_limit = 3
	definition.meter_operations.append(_make_meter_spec(&"test.meter.health", -5.0))
	var first_result: GameCommandResult = _apply_to_fixture(fixture, definition, &"test.effect.periodic_stack.first")
	var second_result: GameCommandResult = _apply_to_fixture(fixture, definition, &"test.effect.periodic_stack.second")
	var meters: GameMeters = fixture.get("meters") as GameMeters
	var effects: GameEffects = fixture.get("effects") as GameEffects
	_assert_true(first_result.is_success() and second_result.is_success(), "Repeated ADD_STACK applications should succeed.")
	_assert_float(meters.get_current(&"test.meter.health"), 95.0, "Existing application flow should execute meter operation once on initial effect application.")
	effects.advance_time(1.0, _make_context(fixture, &"test.effect.periodic_stack.tick"))
	_assert_float(meters.get_current(&"test.meter.health"), 85.0, "Periodic meter delta should scale by the current two-stack count.")
	_free_fixture(fixture)

func _run_all_tests() -> void:
	_test_spec_validation()
	_test_definition_nested_validation()
	_test_legacy_migration()
	_test_runtime_application_and_cleanup()
	_test_attribute_atomicity()
	_test_meter_failure_cleans_modifier()
	_test_instant_cleanup()
	_test_periodic_stack_scaling()

func _print_summary() -> void:
	print("============================================================")
	print("GCA Effect typed-spec tests: %s passed, %s failed" % [_passed, _failed])
	for message: String in _failure_messages:
		print("FAILED: %s" % message)
	print("============================================================")
