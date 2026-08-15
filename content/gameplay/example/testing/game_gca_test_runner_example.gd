extends Node3D
class_name GameGCATestRunnerExample

signal test_started(test_id: StringName)
signal test_completed(test_id: StringName, passed: bool, message: String)
signal suite_completed(all_passed: bool, passed_count: int, total_count: int)

# ======= CONSTS =========
const MINE_SCENE: PackedScene = preload("res://content/gameplay/example/mine/prop_mine_example.tscn")
const DOOR_SCENE: PackedScene = preload("res://content/gameplay/example/door/prop_door_example.tscn")
const CHARACTER_SCENE: PackedScene = preload("res://content/gameplay/example/character/ent_third_person_character_example.tscn")
const CHEST_SCENE: PackedScene = preload("res://content/gameplay/example/chest/prop_chest_example.tscn")
const ENEMY_SCENE: PackedScene = preload("res://content/gameplay/example/enemy/ent_enemy_example.tscn")
const NPC_SCENE: PackedScene = preload("res://content/gameplay/example/npc/ent_npc_example.tscn")
const INVENTORY_SCENE: PackedScene = preload("res://content/gameplay/example/inventory/inventory_equipment_example.tscn")
const DIALOGUE_SCENE: PackedScene = preload("res://content/gameplay/example/dialogue/dialogue_reward_example.tscn")
const GOAP_SCENE: PackedScene = preload("res://content/gameplay/example/goap/goap_survival_example.tscn")

# ======== EXPORT =========
@export var fixtures_root: Node = null
@export var results_container: VBoxContainer = null
@export var summary_label: Label = null
@export var run_button: Button = null
@export var auto_run: bool = true
@export_range(0.1, 10.0, 0.1) var goap_timeout: float = 3.0

# ======== PRIVATE VAR ======
var _results: Array[Dictionary] = []
var _running: bool = false
var _all_passed: bool = false

# ======= OVERRIDE =======
func _ready() -> void:
	if run_button != null:
		var callable: Callable = Callable(self, "_on_run_pressed")
		if not run_button.pressed.is_connected(callable):
			run_button.pressed.connect(callable)
	if auto_run and not Engine.is_editor_hint():
		run_all_tests()

# ====== HELPERS ========
func _record(test_id: StringName, passed: bool, message: String) -> void:
	_results.append({"test_id": test_id, "passed": passed, "message": message})
	if results_container != null:
		var label := Label.new()
		label.text = "%s %s — %s" % ["PASS" if passed else "FAIL", test_id, message]
		label.add_theme_color_override("font_color", Color(0.25, 0.95, 0.45) if passed else Color(1.0, 0.3, 0.3))
		results_container.add_child(label)
	print("[GCA TEST] %s %s — %s" % ["PASS" if passed else "FAIL", test_id, message])
	test_completed.emit(test_id, passed, message)

func _begin_test(test_id: StringName) -> void:
	test_started.emit(test_id)

func _instantiate_fixture(scene: PackedScene) -> Node:
	var instance: Node = scene.instantiate()
	if fixtures_root != null:
		fixtures_root.add_child(instance)
	else:
		add_child(instance)
	return instance

func _clear_fixtures() -> void:
	var root: Node = fixtures_root if fixtures_root != null else self
	for child: Node in root.get_children():
		child.queue_free()

func _test_attribute_formula() -> void:
	var test_id: StringName = &"core.attribute_formula"
	_begin_test(test_id)
	var definition := GameAttributeDefinition.new()
	definition.attribute_id = &"test.attribute"
	definition.default_base = 100.0
	var value := GameAttributeValue.new(definition)
	value.add_modifier(GameAttributeModifier.new(1, definition.attribute_id, GameAttributeModifier.Operation.ADD, 20.0, &"test.add"))
	value.add_modifier(GameAttributeModifier.new(2, definition.attribute_id, GameAttributeModifier.Operation.INCREASE, 0.5, &"test.increase"))
	var actual: float = value.get_final()
	_record(test_id, is_equal_approx(actual, 180.0), "Expected 180, got %.2f." % actual)

func _test_meter_depletion() -> void:
	var test_id: StringName = &"core.meter_depletion"
	_begin_test(test_id)
	var definition := GameMeterDefinition.new()
	definition.meter_id = &"test.health"
	definition.constant_maximum = 100.0
	definition.initial_policy = GameMeterDefinition.InitialPolicy.FULL
	var value := GameMeterValue.new(definition, 100.0)
	var change: Dictionary = value.set_current(0.0)
	_record(test_id, bool(change.get("depleted_crossed", false)) and value.is_depleted(), "Meter crossed depletion exactly once.")

func _test_ability_contract() -> void:
	var test_id: StringName = &"core.ability_definition"
	_begin_test(test_id)
	var definition := GameAbilityDefinition.new()
	definition.ability_id = &"test.ability"
	var operations: Array[GameAbilityOperation] = [GameAbilityOperation.new()]
	definition.operations = operations
	_record(test_id, definition.is_valid(), "Definition/operation contract is valid.")

func _test_control_arbiter() -> void:
	var test_id: StringName = &"core.control_arbiter"
	_begin_test(test_id)
	var arbiter := GameControlArbiter.new()
	var player := GameControlSource.new()
	player.source_id = &"test.player"
	player.priority = 1
	var scripted := GameControlSource.new()
	scripted.source_id = &"test.scripted"
	scripted.priority = 100
	arbiter.register_source(player)
	arbiter.register_source(scripted)
	arbiter.request_ownership(player.source_id, GameControlChannels.MOVEMENT, player.priority)
	arbiter.request_ownership(scripted.source_id, GameControlChannels.MOVEMENT, scripted.priority, true)
	var preempted: bool = arbiter.owns_channel(scripted.source_id, GameControlChannels.MOVEMENT)
	arbiter.release_ownership(scripted.source_id, GameControlChannels.MOVEMENT)
	var restored: bool = arbiter.owns_channel(player.source_id, GameControlChannels.MOVEMENT)
	_record(test_id, preempted and restored, "Temporary override restored the previous owner.")
	player.free()
	scripted.free()
	arbiter.free()

func _test_world_resolver() -> void:
	var test_id: StringName = &"core.world_resolver"
	_begin_test(test_id)
	var resolver := GameObjectResolver.new()
	var first: GameObjectHandle = resolver.register_known(&"test.object")
	var second: GameObjectHandle = resolver.resolve(&"test.object")
	_record(test_id, first == second and first.is_known(), "Resolver returns one canonical stable handle.")
	resolver.free()

func _test_interaction_offer() -> void:
	var test_id: StringName = &"core.interaction_offer"
	_begin_test(test_id)
	var handle := GameObjectHandle.new(&"test.target")
	var offer := GameInteractionOffer.new(&"test.open", &"verb.open", handle)
	offer.set_command_id(&"test.command.open")
	_record(test_id, offer.is_valid(), "Runtime interaction offer is valid.")

func _test_tag_source_ownership() -> void:
	var test_id: StringName = &"core.tag_source_ownership"
	_begin_test(test_id)
	var tags := GameTagContainer.new()
	tags.reject_unknown_tags = false
	var first: GameTagSourceHandle = tags.add_tag(&"status.test", &"source.first", false, false)
	var second: GameTagSourceHandle = tags.add_tag(&"status.test", &"source.second", false, false)
	var before_remove: bool = tags.has_exact_tag(&"status.test")
	tags.remove_tag(first, false)
	var after_first_remove: bool = tags.has_exact_tag(&"status.test")
	tags.remove_tag(second, false)
	var after_second_remove: bool = tags.has_exact_tag(&"status.test")
	_record(test_id, before_remove and after_first_remove and not after_second_remove, "Tag remains until its final source handle is removed.")
	tags.free()

func _test_execution_context_chain() -> void:
	var test_id: StringName = &"core.execution_context_chain"
	_begin_test(test_id)
	var owner := GameObjectHandle.new(&"test.owner")
	var root_context: GameExecutionContext = GameExecutionContext.create_root(1, owner, &"test.root", 1337, 10, "Root")
	var child_context: GameExecutionContext = root_context.create_child(2, owner, &"test.child", "Child")
	var passed: bool = child_context.get_root_operation_id() == root_context.get_root_operation_id() and child_context.get_parent_operation_id() == root_context.get_operation_id() and child_context.get_chain_depth() == 1
	_record(test_id, passed, "Child context preserves root ID, parent ID and deterministic depth.")

func _test_effect_definition_contract() -> void:
	var test_id: StringName = &"core.effect_definition"
	_begin_test(test_id)
	var definition: GameEffectDefinition = preload("res://content/gameplay/example/shared/effect_speed_boost_example.tres")
	_record(test_id, definition.is_valid() and definition.duration_policy == GameEffectDefinition.DurationPolicy.INFINITE, "Infinite example effect passes validation.")

func _test_scene_contract(scene: PackedScene, test_id: StringName, expected_class: StringName) -> Node:
	_begin_test(test_id)
	var instance: Node = _instantiate_fixture(scene)
	await get_tree().process_frame
	var actual_class: StringName = instance.get_script().get_global_name() if instance.get_script() != null else &""
	var passed: bool = actual_class == expected_class and instance.name.ends_with("Example")
	_record(test_id, passed, "Instantiated %s." % actual_class)
	return instance

func _finish_suite() -> void:
	var passed_count: int = 0
	for result: Dictionary in _results:
		if bool(result.get("passed", false)):
			passed_count += 1
	_all_passed = passed_count == _results.size() and not _results.is_empty()
	if summary_label != null:
		summary_label.text = "GCA TESTS: %d/%d PASSED — %s" % [passed_count, _results.size(), "SUCCESS" if _all_passed else "FAILED"]
		summary_label.add_theme_color_override("font_color", Color(0.25, 0.95, 0.45) if _all_passed else Color(1.0, 0.3, 0.3))
	print("[GCA TEST SUITE] %d/%d PASSED — %s" % [passed_count, _results.size(), "SUCCESS" if _all_passed else "FAILED"])
	suite_completed.emit(_all_passed, passed_count, _results.size())

# ====== PUBLIC ========
func run_all_tests() -> void:
	if _running:
		return
	_running = true
	_results.clear()
	_all_passed = false
	_clear_fixtures()
	await get_tree().process_frame
	if results_container != null:
		for child: Node in results_container.get_children():
			child.queue_free()
	_test_attribute_formula()
	_test_meter_depletion()
	_test_ability_contract()
	_test_control_arbiter()
	_test_world_resolver()
	_test_interaction_offer()
	_test_tag_source_ownership()
	_test_execution_context_chain()
	_test_effect_definition_contract()

	var mine_node: Node = await _test_scene_contract(MINE_SCENE, &"example.mine_scene", &"GameMineExample")
	var mine: GameMineExample = mine_node as GameMineExample
	_record(&"example.mine_trigger", mine != null and mine.trigger().is_success() and not mine.is_armed(), "Mine transitions from armed to triggered.")

	var door_node: Node = await _test_scene_contract(DOOR_SCENE, &"example.door_scene", &"GameDoorExample")
	var door: GameDoorExample = door_node as GameDoorExample
	_record(&"example.door_state", door != null and door.open_door().is_success() and door.is_open(), "Door opens through its public command API.")

	var character_node: Node = await _test_scene_contract(CHARACTER_SCENE, &"example.character_scene", &"GameThirdPersonCharacterExample")
	var character: GameThirdPersonCharacterExample = character_node as GameThirdPersonCharacterExample
	_record(&"example.character_dimensions", character != null and character.get_reference_dimensions() == Vector3(1.0, 2.0, 1.0), "Character reference primitive is 1x2x1 metres.")

	var chest_node: Node = await _test_scene_contract(CHEST_SCENE, &"example.chest_scene", &"GameChestExample")
	var chest: GameChestExample = chest_node as GameChestExample
	var chest_ok: bool = chest != null and chest.open_chest().is_success() and chest.take_item(&"example.item.apple").is_success()
	_record(&"example.chest_inventory", chest_ok, "Chest opens and changes its inventory snapshot.")

	var enemy_node: Node = await _test_scene_contract(ENEMY_SCENE, &"example.enemy_scene", &"GameEnemyExample")
	var enemy: GameEnemyExample = enemy_node as GameEnemyExample
	_record(&"example.enemy_control", enemy != null and enemy.has_ai_control(), "Enemy owns movement through mock AI control source.")
	var damage_death_ok: bool = false
	if enemy != null and enemy.kernel != null and enemy.kernel.get_object_context() != null:
		var enemy_context: GameObjectContext = enemy.kernel.get_object_context()
		var enemy_handle: GameObjectHandle = enemy_context.get_object_handle()
		var damage_receiver: GameDamageReceiver = enemy_context.get_capability(GameCapabilityIds.DAMAGE_RECEIVER) as GameDamageReceiver
		var death_policy: GameDeathPolicy = enemy_context.get_capability(GameCapabilityIds.DEATH_POLICY) as GameDeathPolicy
		var damage_context: GameExecutionContext = enemy_context.create_root_execution_context(&"test.damage", "Damage/death integration")
		var damage_tags: Array[StringName] = [&"damage.test"]
		var damage_request := GameDamageRequest.new(enemy_handle, enemy_handle, enemy_handle, 150.0, damage_tags, damage_context)
		if damage_receiver != null and death_policy != null:
			damage_death_ok = damage_receiver.apply_damage(damage_request).is_success() and death_policy.is_dead()
	_record(&"core.damage_death_chain", damage_death_ok, "Damage depleted health and produced one death transition.")

	var npc_node: Node = await _test_scene_contract(NPC_SCENE, &"example.npc_scene", &"GameNPCExample")
	var npc: GameNPCExample = npc_node as GameNPCExample
	_record(&"example.npc_interaction", npc != null and npc.is_dialogue_available(), "NPC exposes a dialogue interaction offer.")

	var inventory_node: Node = await _test_scene_contract(INVENTORY_SCENE, &"integration.inventory_scene", &"GameInventoryEquipmentExample")
	var inventory: GameInventoryEquipmentExample = inventory_node as GameInventoryEquipmentExample
	await get_tree().process_frame
	var inventory_result: GameCommandResult = inventory.get_last_result() if inventory != null else null
	var inventory_binding_ok: bool = inventory_result != null and inventory_result.is_success() and not inventory.get_binding_snapshot().is_empty()
	_record(&"integration.inventory_binding", inventory_binding_ok, "Inventory adapter created item-owned effect/grant bindings.")
	_record(&"integration.inventory_effect", inventory != null and is_equal_approx(inventory.get_owner_speed(), 7.0), "Equipment effect changed movement speed from 5 to 7 through GameEffects.")
	var inventory_activation: GameCommandResult = inventory.activate_granted_ability() if inventory != null else null
	_record(&"integration.inventory_ability", inventory_activation != null and inventory_activation.is_success(), "Ability granted by equipment completed through GameAbilities.")

	var dialogue_node: Node = await _test_scene_contract(DIALOGUE_SCENE, &"integration.dialogue_scene", &"GameDialogueRewardExample")
	var dialogue: GameDialogueRewardExample = dialogue_node as GameDialogueRewardExample
	var dialogue_ok: bool = dialogue != null and dialogue.grant_reward() and dialogue.has_received_reward()
	_record(&"integration.dialogue_reward", dialogue_ok, "Dialogue adapter granted the configured ability by stable object ID.")

	var goap_node: Node = await _test_scene_contract(GOAP_SCENE, &"integration.goap_scene", &"GameGOAPSurvivalExample")
	var goap: GameGOAPSurvivalExample = goap_node as GameGOAPSurvivalExample
	var elapsed: float = 0.0
	while goap != null and not goap.is_sequence_completed() and elapsed < goap_timeout:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_record(&"integration.goap_sequence", goap != null and goap.is_sequence_completed(), "GOAP completed find/take/cook/eat/sleep sequence in %.2fs." % elapsed)

	_finish_suite()
	_running = false

func all_tests_passed() -> bool:
	return _all_passed

func get_results() -> Array[Dictionary]:
	return _results.duplicate(true)

# ===== SLOTS =======
func _on_run_pressed() -> void:
	run_all_tests()
