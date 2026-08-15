@tool
extends GameFeature
## Optional ability-slot loadout for owner-local control routing.
##
## Slots bind to concrete grant handles rather than shared ability definitions. Multiple
## source-owned bindings can coexist; the highest-priority valid grant is resolved without
## destroying lower-priority bindings, so equipment/effects can override and later reveal
## the previous assignment automatically.
class_name GameAbilityLoadout

## Emitted after a binding is added or removed from a logical slot.
signal slot_bindings_changed(slot_id: StringName)

# ======== EXPORT =========
@export var initial_slots: Array[GameAbilitySlotDefinition] = []

# ======== PRIVATE VAR ======
var _abilities: GameAbilities = null
var _bindings: Dictionary = {}
var _binding_ids_by_slot: Dictionary = {}
var _binding_counter: int = 0

# ======= OVERRIDE =======
## Provides the loadout capability and requires read access to local ability grants.
func _init() -> void:
	feature_id = &"object.ability_loadout"
	if provided_capabilities.is_empty():
		var spec := GameCapabilitySpec.new()
		spec.capability_id = GameCapabilityIds.ABILITIES_LOADOUT
		spec.cardinality = GameCapabilityCardinality.Type.EXCLUSIVE
		provided_capabilities.append(spec)
	if required_dependencies.is_empty():
		var dependency := GameCapabilityDependency.new()
		dependency.capability_id = GameCapabilityIds.ABILITIES_QUERY
		required_dependencies.append(dependency)

## Returns editor warnings for invalid or duplicate initial slot assignments.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = super()
	var slot_ids: Dictionary = {}
	for definition: GameAbilitySlotDefinition in initial_slots:
		if definition == null or not definition.is_valid():
			warnings.append("GameAbilityLoadout contains an invalid initial slot definition.")
			continue
		if slot_ids.has(definition.slot_id):
			warnings.append("Duplicate initial ability slot '%s'." % definition.slot_id)
		else:
			slot_ids[definition.slot_id] = true
	return warnings

## Resolves GameAbilities and creates initial bindings against already granted abilities.
func on_game_initialize() -> GameCommandResult:
	_bindings.clear()
	_binding_ids_by_slot.clear()
	_binding_counter = 0
	_abilities = get_dependency(GameCapabilityIds.ABILITIES_QUERY) as GameAbilities
	if _abilities == null:
		return GameCommandResult.configuration_error(
			&"missing_abilities_query",
			"GameAbilityLoadout requires the abilities.query capability."
		)
	for definition: GameAbilitySlotDefinition in initial_slots:
		if definition == null or not definition.is_valid():
			return GameCommandResult.configuration_error(
				&"invalid_initial_ability_slot",
				"GameAbilityLoadout contains an invalid initial slot definition."
			)
		var result: GameCommandResult = bind_ability(
			definition.slot_id,
			definition.ability.ability_id,
			&"loadout.initial",
			definition.priority
		)
		if not result.is_success():
			return GameCommandResult.configuration_error(
				&"initial_slot_ability_not_granted",
				"Initial slot '%s' references ability '%s', but no matching grant exists." % [
					definition.slot_id,
					definition.ability.ability_id,
				]
			)
	return GameCommandResult.success_changed(&"ability_loadout_initialized")

## Clears runtime bindings and cached ability access.
func on_game_shutdown() -> void:
	_bindings.clear()
	_binding_ids_by_slot.clear()
	_binding_counter = 0
	_abilities = null

## Drops the cached abilities dependency when it disappears.
func on_capability_lost(capability_id: StringName) -> void:
	if capability_id == GameCapabilityIds.ABILITIES_QUERY:
		_abilities = null

# ====== HELPERS ========
func _sort_slot_bindings(slot_id: StringName) -> void:
	var ids: Array[int] = _binding_ids_by_slot.get(slot_id, [])
	ids.sort_custom(
		func(a_id: int, b_id: int) -> bool:
			var a: GameAbilitySlotBinding = _bindings.get(a_id) as GameAbilitySlotBinding
			var b: GameAbilitySlotBinding = _bindings.get(b_id) as GameAbilitySlotBinding
			if a == null:
				return false
			if b == null:
				return true
			if a.get_priority() != b.get_priority():
				return a.get_priority() > b.get_priority()
			return a.get_handle_id() > b.get_handle_id()
	)
	_binding_ids_by_slot[slot_id] = ids

func _erase_binding(binding: GameAbilitySlotBinding) -> void:
	if binding == null:
		return
	var slot_id: StringName = binding.get_slot_id()
	var ids: Array[int] = _binding_ids_by_slot.get(slot_id, [])
	ids.erase(binding.get_handle_id())
	if ids.is_empty():
		_binding_ids_by_slot.erase(slot_id)
	else:
		_binding_ids_by_slot[slot_id] = ids
	_bindings.erase(binding.get_handle_id())

# ====== PUBLIC ========
## Adds a source-owned slot binding to one concrete grant handle.
func bind_grant(
	slot_id: StringName,
	grant_handle_id: int,
	source_id: StringName = &"",
	priority: int = 0
) -> GameCommandResult:
	if slot_id.is_empty():
		return GameCommandResult.configuration_error(
			&"ability_slot_id_empty",
			"Ability slot ID cannot be empty."
		)
	if _abilities == null:
		return GameCommandResult.missing_capability(GameCapabilityIds.ABILITIES_QUERY)
	if not _abilities.has_grant(grant_handle_id):
		return GameCommandResult.rejected_permanent(
			&"unknown_grant",
			"Ability slot cannot bind an unknown grant handle."
		)

	_binding_counter += 1
	var binding := GameAbilitySlotBinding.new(
		_binding_counter,
		slot_id,
		grant_handle_id,
		source_id,
		priority
	)
	_bindings[_binding_counter] = binding
	var ids: Array[int] = _binding_ids_by_slot.get(slot_id, [])
	ids.append(_binding_counter)
	_binding_ids_by_slot[slot_id] = ids
	_sort_slot_bindings(slot_id)
	slot_bindings_changed.emit(slot_id)
	return GameCommandResult.success_changed(&"ability_slot_bound", binding)

## Resolves the currently selected grant for an ability ID and binds that exact grant.
func bind_ability(
	slot_id: StringName,
	ability_id: StringName,
	source_id: StringName = &"",
	priority: int = 0
) -> GameCommandResult:
	if _abilities == null:
		return GameCommandResult.missing_capability(GameCapabilityIds.ABILITIES_QUERY)
	var grant_handle_id: int = _abilities.resolve_grant_handle(ability_id)
	if grant_handle_id <= 0:
		return GameCommandResult.rejected_permanent(
			&"ability_not_granted",
			"No enabled grant exists for ability '%s'." % ability_id
		)
	return bind_grant(slot_id, grant_handle_id, source_id, priority)

## Removes one binding without touching the underlying ability grant.
func unbind(binding_handle_id: int) -> GameCommandResult:
	var binding: GameAbilitySlotBinding = _bindings.get(binding_handle_id) as GameAbilitySlotBinding
	if binding == null:
		return GameCommandResult.rejected_permanent(
			&"unknown_slot_binding",
			"Unknown ability slot binding handle."
		)
	var slot_id: StringName = binding.get_slot_id()
	_erase_binding(binding)
	slot_bindings_changed.emit(slot_id)
	return GameCommandResult.success_changed(&"ability_slot_unbound")

## Removes every binding owned by one source key and leaves unrelated bindings intact.
func unbind_source(source_id: StringName) -> GameCommandResult:
	var handle_ids: Array[int] = []
	for handle_id: int in _bindings.keys():
		var binding: GameAbilitySlotBinding = _bindings[handle_id] as GameAbilitySlotBinding
		if binding != null and binding.get_source_id() == source_id:
			handle_ids.append(handle_id)
	handle_ids.sort()

	if handle_ids.is_empty():
		return GameCommandResult.success_unchanged(&"ability_slot_source_not_bound")

	var changed_slots: Dictionary = {}
	for handle_id: int in handle_ids:
		var binding: GameAbilitySlotBinding = _bindings.get(handle_id) as GameAbilitySlotBinding
		if binding == null:
			continue
		changed_slots[binding.get_slot_id()] = true
		_erase_binding(binding)

	for slot_id: StringName in changed_slots.keys():
		slot_bindings_changed.emit(slot_id)
	return GameCommandResult.success_changed(&"ability_slot_source_unbound", handle_ids)

## Returns the highest-priority binding whose grant still exists and is enabled.
## This query is side-effect free; stale bindings are ignored but remain diagnosable.
func get_active_binding(slot_id: StringName) -> GameAbilitySlotBinding:
	if _abilities == null:
		return null
	for handle_id: int in _binding_ids_by_slot.get(slot_id, []):
		var binding: GameAbilitySlotBinding = _bindings.get(handle_id) as GameAbilitySlotBinding
		if binding != null and _abilities.has_grant(binding.get_grant_handle_id()):
			return binding
	return null

## Returns the active grant handle for a logical slot, or 0 when the slot is unbound.
func resolve_slot(slot_id: StringName) -> int:
	var binding: GameAbilitySlotBinding = get_active_binding(slot_id)
	return binding.get_grant_handle_id() if binding != null else 0

## Returns logical slots in deterministic order.
func get_slot_ids() -> Array[StringName]:
	var slot_ids: Array[StringName] = []
	for slot_id: StringName in _binding_ids_by_slot.keys():
		slot_ids.append(slot_id)
	slot_ids.sort()
	return slot_ids

## Returns a diagnostic snapshot of all bindings and currently active grants.
func get_debug_snapshot() -> Dictionary:
	var slots: Dictionary = {}
	for slot_id: StringName in get_slot_ids():
		var bindings: Array[Dictionary] = []
		for handle_id: int in _binding_ids_by_slot.get(slot_id, []):
			var binding: GameAbilitySlotBinding = _bindings.get(handle_id) as GameAbilitySlotBinding
			if binding == null:
				continue
			var record: Dictionary = binding.to_dictionary()
			record["grant_valid"] = _abilities != null and _abilities.has_grant(
				binding.get_grant_handle_id()
			)
			bindings.append(record)
		slots[slot_id] = {
			"active_grant_handle_id": resolve_slot(slot_id),
			"bindings": bindings,
		}
	return {"slots": slots}
