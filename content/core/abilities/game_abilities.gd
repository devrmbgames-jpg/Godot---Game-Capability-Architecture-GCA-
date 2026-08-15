@tool
extends GameFeature
## Central feature for ability grants, activation, execution, costs, and cooldowns.
##
## Keeps shared definitions immutable, selects owner-specific grants, performs
## side-effect-free activation queries, commits costs atomically, owns execution
## channels and tags, and publishes ability lifecycle events.
class_name GameAbilities

# ======== EXPORT =========
@export var initial_abilities: Array[GameAbilityDefinition] = []
@export var grant_selection_policy: GameAbilityDefinition.GrantSelectionPolicy = GameAbilityDefinition.GrantSelectionPolicy.HIGHEST_LEVEL
@export_range(1, 64, 1) var max_active_executions: int = 16

# ======== PRIVATE VAR ======
var _grants: Dictionary = {}
var _grant_ids_by_ability: Dictionary = {}
var _executions: Dictionary = {}
var _cooldowns: Dictionary = {}
var _occupied_channels: Dictionary = {}
var _grant_counter: int = 0
var _execution_counter: int = 0
var _meters: GameMeters = null
var _effects: GameEffects = null
var _tags: GameTagContainer = null

# ======= OVERRIDE =======
## Configures ability capabilities and optional local gameplay dependencies.
func _init() -> void:
	feature_id = &"object.abilities"
	if provided_capabilities.is_empty():
		for capability_id: StringName in [GameCapabilityIds.ABILITIES_OWNER, GameCapabilityIds.ABILITIES_QUERY, GameCapabilityIds.ABILITIES_ACTIVATE, GameCapabilityIds.ABILITIES_GRANT, GameCapabilityIds.ABILITIES_CANCEL]:
			var spec := GameCapabilitySpec.new()
			spec.capability_id = capability_id
			spec.cardinality = GameCapabilityCardinality.Type.EXCLUSIVE
			provided_capabilities.append(spec)
	if optional_dependencies.is_empty():
		for capability_id: StringName in [GameCapabilityIds.METERS_MODIFY, GameCapabilityIds.EFFECTS_RECEIVER, GameCapabilityIds.TAGS_MODIFY]:
			var dependency := GameCapabilityDependency.new()
			dependency.capability_id = capability_id
			dependency.required = false
			optional_dependencies.append(dependency)

## Returns editor warnings for invalid or duplicated initial definitions.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = super()
	var ids: Dictionary = {}
	for definition: GameAbilityDefinition in initial_abilities:
		if definition == null or not definition.is_valid():
			warnings.append("GameAbilities contains an invalid initial ability definition.")
		elif ids.has(definition.ability_id):
			warnings.append("Duplicate initial ability ID '%s'." % definition.ability_id)
		else:
			ids[definition.ability_id] = true
	return warnings

## Resets runtime state, resolves optional dependencies, and grants initial abilities.
func on_game_initialize() -> GameCommandResult:
	_grants.clear(); _grant_ids_by_ability.clear(); _executions.clear(); _cooldowns.clear(); _occupied_channels.clear()
	_grant_counter = 0; _execution_counter = 0
	_meters = get_dependency(GameCapabilityIds.METERS_MODIFY) as GameMeters
	_effects = get_dependency(GameCapabilityIds.EFFECTS_RECEIVER) as GameEffects
	_tags = get_dependency(GameCapabilityIds.TAGS_MODIFY) as GameTagContainer
	var context: GameObjectContext = get_context()
	for definition: GameAbilityDefinition in initial_abilities:
		if definition == null or not definition.is_valid():
			return GameCommandResult.configuration_error(&"invalid_initial_ability", "An initial ability definition is invalid.")
		var result: GameCommandResult = grant_ability(definition, context.get_object_handle(), definition.ability_id)
		if not result.is_success(): return result
	return GameCommandResult.success_changed(&"abilities_initialized")

## Cancels active executions, invalidates grants, and clears owner runtime state.
func on_game_shutdown() -> void:
	for execution_id: int in _executions.keys(): cancel_execution(execution_id, &"shutdown")
	for grant: GameAbilityGrant in _grants.values(): grant.invalidate()
	_grants.clear(); _grant_ids_by_ability.clear(); _executions.clear(); _cooldowns.clear(); _occupied_channels.clear()

# ====== HELPERS ========
func _emit_event(event_id: StringName, execution_context: GameExecutionContext, payload: Dictionary) -> void:
	var context: GameObjectContext = get_context()
	if context != null:
		publish_local_event(GameLocalEvent.new(event_id, context.get_object_handle(), execution_context, payload))

func _select_grant(ability_id: StringName, explicit_handle_id: int = 0) -> GameAbilityGrant:
	if explicit_handle_id > 0: return _grants.get(explicit_handle_id) as GameAbilityGrant
	var candidates: Array[GameAbilityGrant] = []
	for handle_id: int in _grant_ids_by_ability.get(ability_id, []):
		var grant: GameAbilityGrant = _grants.get(handle_id) as GameAbilityGrant
		if grant != null and grant.is_enabled(): candidates.append(grant)
	if candidates.is_empty(): return null
	candidates.sort_custom(func(a: GameAbilityGrant, b: GameAbilityGrant) -> bool:
		match grant_selection_policy:
			GameAbilityDefinition.GrantSelectionPolicy.SOURCE_PRIORITY:
				if a.get_source_priority() != b.get_source_priority(): return a.get_source_priority() > b.get_source_priority()
			GameAbilityDefinition.GrantSelectionPolicy.HIGHEST_LEVEL:
				if a.get_level() != b.get_level(): return a.get_level() > b.get_level()
		return a.get_handle_id() < b.get_handle_id())
	return candidates[0]

func _validate_definition(grant: GameAbilityGrant, request: GameAbilityActivationRequest) -> GameAbilityActivationQueryResult:
	var definition: GameAbilityDefinition = grant.get_definition()
	var context: GameObjectContext = get_context()
	if not grant.is_enabled(): return GameAbilityActivationQueryResult.unavailable(&"disabled_grant", "Grant is disabled.", grant.get_handle_id())
	if not grant.has_charge(): return GameAbilityActivationQueryResult.unavailable(&"no_charges", "Grant has no charges.", grant.get_handle_id())
	for capability_id: StringName in definition.required_owner_capabilities:
		if context.get_capability(capability_id) == null: return GameAbilityActivationQueryResult.unavailable(&"missing_capability", "Required owner capability '%s' is missing." % capability_id, grant.get_handle_id(), 0.0, {"capability_id": capability_id})
	for tag_id: StringName in definition.required_owner_tags:
		if not context.has_tag_or_child(tag_id): return GameAbilityActivationQueryResult.unavailable(&"missing_required_tag", "Required owner tag '%s' is missing." % tag_id, grant.get_handle_id())
	for tag_id: StringName in definition.blocked_owner_tags:
		if context.has_tag_or_child(tag_id): return GameAbilityActivationQueryResult.unavailable(&"blocked_by_tag", "Owner tag '%s' blocks the ability." % tag_id, grant.get_handle_id())
	var cooldown_remaining: float = get_cooldown_remaining(definition.get_resolved_cooldown_key())
	if cooldown_remaining > 0.0: return GameAbilityActivationQueryResult.unavailable(&"cooldown_active", "Ability cooldown is active.", grant.get_handle_id(), cooldown_remaining)
	for requirement: GameAbilityRequirement in definition.requirements:
		var requirement_result: GameAbilityActivationQueryResult = requirement.evaluate(self, grant, request)
		if not requirement_result.is_available(): return requirement_result
	for cost: GameAbilityCost in definition.costs:
		if cost.timing != GameAbilityCost.Timing.ON_COMMIT: continue
		var cost_result: GameCommandResult = cost.can_pay(self, grant, request)
		if not cost_result.is_success(): return GameAbilityActivationQueryResult.unavailable(cost_result.get_reason_code(), cost_result.get_debug_message(), grant.get_handle_id())
	for channel_id: StringName in definition.occupied_channels:
		if _occupied_channels.has(channel_id): return GameAbilityActivationQueryResult.unavailable(&"concurrency_denied", "Ability channel '%s' is occupied." % channel_id, grant.get_handle_id())
	return GameAbilityActivationQueryResult.available(grant.get_handle_id())

func _commit_execution(execution: GameAbilityExecution) -> GameCommandResult:
	var grant: GameAbilityGrant = execution.get_grant()
	var request: GameAbilityActivationRequest = execution.get_request()
	var committed: Array[Dictionary] = []
	for cost: GameAbilityCost in grant.get_definition().costs:
		if cost.timing != GameAbilityCost.Timing.ON_COMMIT: continue
		var prepared: Variant = cost.prepare(self, grant, request)
		var result: GameCommandResult = cost.commit(self, grant, request, prepared)
		if not result.is_success():
			for index: int in range(committed.size() - 1, -1, -1):
				var record: Dictionary = committed[index]
				(record.cost as GameAbilityCost).rollback(self, grant, request, record.prepared)
			return result
		committed.append({"cost": cost, "prepared": prepared}); execution.add_prepared_cost(cost, prepared)
	if not grant.consume_charge(): return GameCommandResult.new(GameCommandResult.Status.INSUFFICIENT_RESOURCE, &"no_charges", "Grant has no charges.")
	var definition: GameAbilityDefinition = grant.get_definition()
	if definition.cooldown_duration > 0.0:
		_cooldowns[definition.get_resolved_cooldown_key()] = GameAbilityCooldownState.new(definition.get_resolved_cooldown_key(), definition.cooldown_duration, grant.get_handle_id())
	for channel_id: StringName in definition.occupied_channels: _occupied_channels[channel_id] = execution.get_execution_id()
	if _tags != null:
		for tag_id: StringName in definition.granted_tags_during_execution:
			execution.add_owned_tag_handle(_tags.add_tag(tag_id, definition.ability_id))
	grant.add_execution(execution.get_execution_id()); execution.set_state(GameAbilityExecution.State.COMMITTED)
	return GameCommandResult.success_changed(&"ability_committed")

func _cleanup_execution(execution: GameAbilityExecution) -> void:
	var definition: GameAbilityDefinition = execution.get_definition()
	for channel_id: StringName in definition.occupied_channels:
		if int(_occupied_channels.get(channel_id, 0)) == execution.get_execution_id(): _occupied_channels.erase(channel_id)
	if _tags != null:
		for handle: GameTagSourceHandle in execution.get_owned_tag_handles(): _tags.remove_tag(handle)
	execution.get_grant().remove_execution(execution.get_execution_id())

func _run_execution(execution: GameAbilityExecution) -> GameCommandResult:
	execution.set_state(GameAbilityExecution.State.EXECUTING)
	var operations: Array[GameAbilityOperation] = execution.get_definition().operations
	while execution.get_operation_index() < operations.size():
		var operation: GameAbilityOperation = operations[execution.get_operation_index()]
		var result: GameCommandResult = operation.execute(self, execution)
		if not result.is_success() and not operation.continue_on_failure:
			execution.set_failure_reason(result.get_reason_code()); execution.set_state(GameAbilityExecution.State.FAILED); _cleanup_execution(execution)
			_emit_event(&"ability_failed", execution.get_execution_context(), {"ability_id": execution.get_definition().ability_id, "execution_id": execution.get_execution_id(), "reason": result.get_reason_code()})
			return result
		execution.advance_operation()
	execution.set_state(GameAbilityExecution.State.COMPLETED); _cleanup_execution(execution)
	_emit_event(&"ability_completed", execution.get_execution_context(), {"ability_id": execution.get_definition().ability_id, "execution_id": execution.get_execution_id()})
	return GameCommandResult.success_changed(&"ability_completed", execution)

# ====== PUBLIC ========
## Returns the resolved meters dependency used by meter costs.
func get_meters() -> GameMeters: return _meters
## Returns the resolved local effects feature used by operations.
func get_effects() -> GameEffects: return _effects
## Returns the resolved tag container used for execution-owned tags.
func get_tags() -> GameTagContainer: return _tags

## Creates a source-owned grant for [param definition].
## Multiple grants of the same ability ID remain independent.
func grant_ability(definition: GameAbilityDefinition, source_handle: GameObjectHandle = null, source_definition_id: StringName = &"", level: int = 1, charges: int = -1, source_priority: int = 0, runtime_overrides: Dictionary = {}) -> GameCommandResult:
	if definition == null or not definition.is_valid(): return GameCommandResult.configuration_error(&"invalid_ability_definition", "Ability definition is invalid.")
	_grant_counter += 1
	var grant := GameAbilityGrant.new(_grant_counter, definition, get_context().get_object_handle(), source_handle, source_definition_id, level, charges, source_priority, runtime_overrides)
	_grants[_grant_counter] = grant
	var ids: Array[int] = _grant_ids_by_ability.get(definition.ability_id, []); ids.append(_grant_counter); _grant_ids_by_ability[definition.ability_id] = ids
	return GameCommandResult.success_changed(&"ability_granted", grant)

## Revokes one grant by handle and cancels only its active executions.
func revoke_grant(handle_id: int, reason: StringName = &"revoked") -> GameCommandResult:
	var grant: GameAbilityGrant = _grants.get(handle_id) as GameAbilityGrant
	if grant == null: return GameCommandResult.rejected_permanent(&"unknown_grant", "Unknown grant handle.")
	for execution_id: int in grant.get_active_execution_ids(): cancel_execution(execution_id, reason)
	var ids: Array[int] = _grant_ids_by_ability.get(grant.get_definition().ability_id, []); ids.erase(handle_id)
	if ids.is_empty(): _grant_ids_by_ability.erase(grant.get_definition().ability_id)
	else: _grant_ids_by_ability[grant.get_definition().ability_id] = ids
	grant.invalidate(); _grants.erase(handle_id)
	return GameCommandResult.success_changed(&"ability_revoked")

## Checks activation availability without mutating costs, cooldowns, or executions.
func query_activation(request: GameAbilityActivationRequest) -> GameAbilityActivationQueryResult:
	if request == null or request.get_execution_context() == null: return GameAbilityActivationQueryResult.unavailable(&"invalid_request", "Activation request is incomplete.")
	var grant: GameAbilityGrant = _select_grant(request.get_ability_id(), request.get_grant_handle_id())
	if grant == null: return GameAbilityActivationQueryResult.unavailable(&"no_grant", "No matching ability grant exists.")
	return _validate_definition(grant, request)

## Validates, prepares, commits, and executes one activation request.
func activate(request: GameAbilityActivationRequest) -> GameCommandResult:
	if _executions.size() >= max_active_executions: return GameCommandResult.rejected_temporary(&"execution_limit", "Maximum active executions reached.")
	var query_result: GameAbilityActivationQueryResult = query_activation(request)
	if not query_result.is_available():
		if query_result.get_reason_code() == &"cooldown_active": return GameCommandResult.new(GameCommandResult.Status.COOLDOWN_ACTIVE, query_result.get_reason_code(), query_result.get_debug_message(), 0, query_result.to_dictionary())
		return GameCommandResult.rejected_temporary(query_result.get_reason_code(), query_result.get_debug_message(), query_result.to_dictionary())
	var grant: GameAbilityGrant = _grants[query_result.get_grant_handle_id()]
	_execution_counter += 1
	var child_context: GameExecutionContext = get_context().create_child_execution_context(request.get_execution_context(), &"ability.execute", "Ability %s" % grant.get_definition().ability_id)
	var execution := GameAbilityExecution.new(_execution_counter, grant, request, child_context)
	_executions[_execution_counter] = execution; execution.set_state(GameAbilityExecution.State.VALIDATED); execution.set_state(GameAbilityExecution.State.PREPARED)
	var commit_result: GameCommandResult = _commit_execution(execution)
	if not commit_result.is_success(): _executions.erase(_execution_counter); return commit_result
	_emit_event(&"ability_started", child_context, {"ability_id": grant.get_definition().ability_id, "grant_handle_id": grant.get_handle_id(), "execution_id": execution.get_execution_id()})
	return _run_execution(execution)

## Cancels one active execution, invokes operation cleanup, refunds configured costs,
## releases owned tags/channels, and publishes an ability-cancelled event.
func cancel_execution(execution_id: int, reason: StringName = &"cancelled") -> GameCommandResult:
	var execution: GameAbilityExecution = _executions.get(execution_id) as GameAbilityExecution
	if execution == null or execution.is_terminal(): return GameCommandResult.rejected_permanent(&"execution_not_active", "Execution is not active.")
	var operations: Array[GameAbilityOperation] = execution.get_definition().operations
	if execution.get_operation_index() < operations.size(): operations[execution.get_operation_index()].cancel(self, execution, reason)
	for record: Dictionary in execution.get_prepared_costs(): (record.cost as GameAbilityCost).refund(self, execution.get_grant(), execution, record.prepared)
	execution.set_failure_reason(reason); execution.set_state(GameAbilityExecution.State.CANCELLED); _cleanup_execution(execution)
	_emit_event(&"ability_cancelled", execution.get_execution_context(), {"ability_id": execution.get_definition().ability_id, "execution_id": execution_id, "reason": reason})
	return GameCommandResult.new(GameCommandResult.Status.CANCELLED, reason, "Ability execution cancelled.", 0, execution)

## Advances all cooldown states and removes expired keys after iteration.
func advance_time(delta: float) -> void:
	var expired: Array[StringName] = []
	for key: StringName in _cooldowns.keys():
		var cooldown: GameAbilityCooldownState = _cooldowns[key]; cooldown.advance(delta)
		if not cooldown.is_active(): expired.append(key)
	for key: StringName in expired: _cooldowns.erase(key)

## Returns remaining time for a cooldown key, or [code]0.0[/code] when inactive.
func get_cooldown_remaining(key: StringName) -> float:
	var cooldown: GameAbilityCooldownState = _cooldowns.get(key) as GameAbilityCooldownState
	return cooldown.get_remaining() if cooldown != null else 0.0

## Returns grants, executions, cooldowns, and occupied channels for diagnostics.
func get_debug_snapshot() -> Dictionary:
	var grants: Array[Dictionary] = []; for grant: GameAbilityGrant in _grants.values(): grants.append(grant.to_dictionary())
	var executions: Array[Dictionary] = []; for execution: GameAbilityExecution in _executions.values(): executions.append(execution.to_dictionary())
	var cooldowns: Array[Dictionary] = []; for cooldown: GameAbilityCooldownState in _cooldowns.values(): cooldowns.append(cooldown.to_dictionary())
	return {"grants": grants, "executions": executions, "cooldowns": cooldowns, "occupied_channels": _occupied_channels.duplicate()}
