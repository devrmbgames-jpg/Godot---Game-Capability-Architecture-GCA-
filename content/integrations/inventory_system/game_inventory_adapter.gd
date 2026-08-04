extends Node
class_name GameInventoryAdapter

signal equipment_gameplay_applied(item_instance_id: StringName)
signal equipment_gameplay_removed(item_instance_id: StringName)

# ======== EXPORT =========
@export var owner_kernel: GameObjectKernel = null
@export var plugin_inventory: Node = null

# ======== PRIVATE VAR ======
var _bindings: Dictionary = {}

# ====== HELPERS ========
func _get_context() -> GameObjectContext:
	return owner_kernel.get_object_context() if owner_kernel != null else null

func _rollback_binding(binding: Dictionary, context: GameObjectContext) -> void:
	if context == null:
		return
	var effects: GameEffects = context.get_capability(GameCapabilityIds.EFFECTS_DISPEL) as GameEffects
	var abilities: GameAbilities = context.get_capability(GameCapabilityIds.ABILITIES_GRANT) as GameAbilities
	if effects != null:
		for handle_id: int in binding.effects:
			effects.remove_effect(handle_id, &"equipment_rollback")
	if abilities != null:
		for handle_id: int in binding.grants:
			abilities.revoke_grant(handle_id, &"equipment_rollback")

# ====== PUBLIC ========
func apply_equipment(item_id: StringName, effects_to_apply: Array[GameEffectDefinition], abilities_to_grant: Array[GameAbilityDefinition]) -> GameCommandResult:
	if item_id.is_empty():
		return GameCommandResult.configuration_error(&"missing_item_instance_id", "Stable item ID required.")
	if _bindings.has(item_id):
		return GameCommandResult.success_unchanged(&"equipment_already_applied", _bindings[item_id])
	var context: GameObjectContext = _get_context()
	if context == null:
		return GameCommandResult.invalid_target("Inventory owner unresolved.")
	var effects: GameEffects = context.get_capability(GameCapabilityIds.EFFECTS_RECEIVER) as GameEffects
	var abilities: GameAbilities = context.get_capability(GameCapabilityIds.ABILITIES_GRANT) as GameAbilities
	var binding: Dictionary = {"effects": [], "grants": []}
	var execution_context: GameExecutionContext = context.create_root_execution_context(&"inventory.equip", "Equipment")
	for definition: GameEffectDefinition in effects_to_apply:
		if effects == null:
			_rollback_binding(binding, context)
			return GameCommandResult.missing_capability(GameCapabilityIds.EFFECTS_RECEIVER)
		var result: GameCommandResult = effects.apply_effect(definition, context.get_object_handle(), context.get_object_handle(), execution_context)
		if not result.is_success():
			_rollback_binding(binding, context)
			return result
		var active: GameActiveEffect = result.get_payload() as GameActiveEffect
		if active != null:
			binding.effects.append(active.get_handle_id())
	for definition: GameAbilityDefinition in abilities_to_grant:
		if abilities == null:
			_rollback_binding(binding, context)
			return GameCommandResult.missing_capability(GameCapabilityIds.ABILITIES_GRANT)
		var result: GameCommandResult = abilities.grant_ability(definition, context.get_object_handle(), item_id)
		if not result.is_success():
			_rollback_binding(binding, context)
			return result
		var grant: GameAbilityGrant = result.get_payload() as GameAbilityGrant
		if grant != null:
			binding.grants.append(grant.get_handle_id())
	_bindings[item_id] = binding
	equipment_gameplay_applied.emit(item_id)
	return GameCommandResult.success_changed(&"equipment_applied", binding)

func remove_equipment(item_id: StringName) -> GameCommandResult:
	if not _bindings.has(item_id):
		return GameCommandResult.success_unchanged(&"equipment_not_found")
	var context: GameObjectContext = _get_context()
	if context == null:
		return GameCommandResult.invalid_target("Inventory owner unresolved.")
	var binding: Dictionary = _bindings[item_id]
	_rollback_binding(binding, context)
	_bindings.erase(item_id)
	equipment_gameplay_removed.emit(item_id)
	return GameCommandResult.success_changed(&"equipment_removed")

func reconcile(expected_item_ids: Array[StringName]) -> Dictionary:
	var removed: Array[StringName] = []
	for item_id: StringName in _bindings.keys():
		if item_id not in expected_item_ids:
			remove_equipment(item_id)
			removed.append(item_id)
	return {"active": _bindings.keys(), "removed": removed}

func get_bindings_snapshot() -> Dictionary:
	return _bindings.duplicate(true)
