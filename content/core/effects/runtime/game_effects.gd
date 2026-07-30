@tool
extends GameFeature
class_name GameEffects

# ======== PRIVATE VAR ======
var _active_effects: Dictionary = {}
var _handle_counter: int = 0
var _attributes: GameAttributes = null
var _meters: GameMeters = null
var _tags: GameTagContainer = null

# ======= OVERRIDE =======
func _init() -> void:
	feature_id = &"object.effects"
	if provided_capabilities.is_empty():
		for capability_id: StringName in [GameCapabilityIds.EFFECTS_RECEIVER, GameCapabilityIds.EFFECTS_QUERY, GameCapabilityIds.EFFECTS_DISPEL, GameCapabilityIds.EFFECTS_SCHEDULER_HOST]:
			var spec := GameCapabilitySpec.new()
			spec.capability_id = capability_id
			spec.cardinality = GameCapabilityCardinality.Type.EXCLUSIVE
			provided_capabilities.append(spec)
	if optional_dependencies.is_empty():
		for capability_id: StringName in [GameCapabilityIds.ATTRIBUTES_MODIFY, GameCapabilityIds.METERS_MODIFY, GameCapabilityIds.TAGS_MODIFY]:
			var dependency := GameCapabilityDependency.new()
			dependency.capability_id = capability_id
			dependency.required = false
			optional_dependencies.append(dependency)

func on_game_initialize() -> GameCommandResult:
	_attributes = get_dependency(GameCapabilityIds.ATTRIBUTES_MODIFY) as GameAttributes
	_meters = get_dependency(GameCapabilityIds.METERS_MODIFY) as GameMeters
	_tags = get_dependency(GameCapabilityIds.TAGS_MODIFY) as GameTagContainer
	_active_effects.clear()
	_handle_counter = 0
	return GameCommandResult.success_changed(&"effects_initialized")

func on_game_shutdown() -> void:
	var handles: Array = _active_effects.keys()
	for handle_id: int in handles:
		remove_effect(handle_id, &"shutdown")

# ====== HELPERS ========
func _requirements_pass(definition: GameEffectDefinition) -> bool:
	var context: GameObjectContext = get_context()
	if context == null:
		return false
	for tag_id: StringName in definition.required_target_tags:
		if not context.has_tag_or_child(tag_id):
			return false
	for tag_id: StringName in definition.blocked_target_tags:
		if context.has_tag_or_child(tag_id):
			return false
	return true

func _apply_attribute_modifiers(active_effect: GameActiveEffect) -> GameCommandResult:
	var definition: GameEffectDefinition = active_effect.get_definition()
	if definition.attribute_modifiers.is_empty():
		return GameCommandResult.success_unchanged(&"no_attribute_modifiers")
	if _attributes == null:
		return GameCommandResult.missing_capability(GameCapabilityIds.ATTRIBUTES_MODIFY)
	_attributes.begin_transaction()
	for modifier_spec: Dictionary in definition.attribute_modifiers:
		var modifier: GameAttributeModifier = _attributes.add_modifier(
			modifier_spec.get("attribute_id", &""),
			modifier_spec.get("operation", GameAttributeModifier.Operation.ADD),
			float(modifier_spec.get("magnitude", 0.0)) * active_effect.get_stacks(),
			definition.effect_id,
			active_effect.get_handle_id(),
			int(modifier_spec.get("priority", 0))
		)
		if modifier == null:
			_attributes.end_transaction()
			return GameCommandResult.configuration_error(&"invalid_effect_modifier", "Effect modifier target is invalid.")
		active_effect.add_modifier_handle(modifier.get_handle_id())
	_attributes.end_transaction()
	return GameCommandResult.success_changed(&"effect_modifiers_applied")

func _apply_meter_operations(active_effect: GameActiveEffect, execution_context: GameExecutionContext) -> GameCommandResult:
	var definition: GameEffectDefinition = active_effect.get_definition()
	if definition.meter_operations.is_empty():
		return GameCommandResult.success_unchanged(&"no_meter_operations")
	if _meters == null:
		return GameCommandResult.missing_capability(GameCapabilityIds.METERS_MODIFY)
	for operation: Dictionary in definition.meter_operations:
		var result: GameCommandResult = _meters.modify_current(
			operation.get("meter_id", &""),
			float(operation.get("delta", 0.0)) * active_effect.get_stacks(),
			execution_context,
			&"effect_meter_operation"
		)
		if not result.is_success():
			return result
	return GameCommandResult.success_changed(&"effect_meter_operations_applied")

func _grant_tags(active_effect: GameActiveEffect) -> GameCommandResult:
	if _tags == null and not active_effect.get_definition().granted_tags.is_empty():
		return GameCommandResult.missing_capability(GameCapabilityIds.TAGS_MODIFY)
	for tag_id: StringName in active_effect.get_definition().granted_tags:
		var handle: GameTagSourceHandle = _tags.add_tag(tag_id, active_effect.get_definition().effect_id)
		if handle == null:
			return GameCommandResult.configuration_error(&"invalid_effect_tag", "Effect granted tag is invalid.")
		active_effect.add_tag_handle(handle)
	return GameCommandResult.success_changed(&"effect_tags_granted")

func _cleanup_runtime_ownership(active_effect: GameActiveEffect) -> void:
	if _attributes != null:
		for modifier_handle: int in active_effect.get_modifier_handles():
			_attributes.remove_modifier(modifier_handle)
	if _tags != null:
		for tag_handle: GameTagSourceHandle in active_effect.get_tag_handles():
			_tags.remove_tag(tag_handle)

# ====== PUBLIC ========
func apply_effect(definition: GameEffectDefinition, source_handle: GameObjectHandle, instigator_handle: GameObjectHandle, execution_context: GameExecutionContext) -> GameCommandResult:
	if definition == null or not definition.is_valid():
		return GameCommandResult.configuration_error(&"invalid_effect_definition", "Effect definition is invalid.")
	if execution_context == null:
		return GameCommandResult.configuration_error(&"missing_execution_context", "Effect application requires an execution context.")
	if not _requirements_pass(definition):
		return GameCommandResult.rejected_temporary(&"effect_requirements_failed", "Effect requirements or immunity blocked application.")
	for existing: GameActiveEffect in _active_effects.values():
		if existing.get_definition().effect_id != definition.effect_id:
			continue
		match definition.stacking_policy:
			GameEffectDefinition.StackingPolicy.REJECT_DUPLICATE:
				return GameCommandResult.success_unchanged(&"effect_duplicate_rejected", existing)
			GameEffectDefinition.StackingPolicy.REFRESH_DURATION:
				existing.refresh_duration()
				return GameCommandResult.success_changed(&"effect_refreshed", existing)
			GameEffectDefinition.StackingPolicy.ADD_STACK:
				existing.add_stack()
				existing.refresh_duration()
				return GameCommandResult.success_changed(&"effect_stacked", existing)
			GameEffectDefinition.StackingPolicy.REPLACE_OLDER:
				remove_effect(existing.get_handle_id(), &"replaced")
			_:
				pass

	_handle_counter += 1
	var active_effect := GameActiveEffect.new(_handle_counter, definition, source_handle, instigator_handle, execution_context.get_root_operation_id())
	var tag_result: GameCommandResult = _grant_tags(active_effect)
	if not tag_result.is_success():
		return tag_result
	var modifier_result: GameCommandResult = _apply_attribute_modifiers(active_effect)
	if not modifier_result.is_success():
		_cleanup_runtime_ownership(active_effect)
		return modifier_result
	var meter_result: GameCommandResult = _apply_meter_operations(active_effect, execution_context)
	if not meter_result.is_success():
		_cleanup_runtime_ownership(active_effect)
		return meter_result

	if definition.duration_policy == GameEffectDefinition.DurationPolicy.INSTANT:
		_cleanup_runtime_ownership(active_effect)
	else:
		_active_effects[_handle_counter] = active_effect
	return GameCommandResult.success_changed(&"effect_applied", active_effect)

func remove_effect(handle_id: int, _reason: StringName = &"removed") -> bool:
	if not _active_effects.has(handle_id):
		return false
	var active_effect: GameActiveEffect = _active_effects[handle_id]
	_cleanup_runtime_ownership(active_effect)
	_active_effects.erase(handle_id)
	return true

func advance_time(delta: float, execution_context: GameExecutionContext) -> void:
	var expired: Array[int] = []
	for active_effect: GameActiveEffect in _active_effects.values():
		var ticks: int = active_effect.advance(delta)
		for _tick: int in ticks:
			_apply_meter_operations(active_effect, execution_context)
		if active_effect.is_expired():
			expired.append(active_effect.get_handle_id())
	for handle_id: int in expired:
		remove_effect(handle_id, &"expired")

func get_debug_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for active_effect: GameActiveEffect in _active_effects.values():
		result.append(active_effect.to_dictionary())
	return result
