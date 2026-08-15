@tool
extends GameAbilityOperation
## Ability operation that applies one effect definition to normalized targets.
##
## Resolves each target through its handle and requires the target's
## [constant GameCapabilityIds.EFFECTS_RECEIVER] capability.
class_name GameAbilityApplyEffectOperation

# ======== EXPORT =========
@export var effect_definition: GameEffectDefinition = null
@export var apply_to_owner: bool = false

# ====== PUBLIC ========
## Applies [member effect_definition] to the request targets or ability owner.
## Stops at the first invalid target or failed effect application.
func execute(abilities: GameAbilities, execution: GameAbilityExecution) -> GameCommandResult:
	if effect_definition == null or not effect_definition.is_valid():
		return GameCommandResult.configuration_error(&"invalid_operation_effect", "Apply-effect operation has an invalid definition.")
	var request: GameAbilityActivationRequest = execution.get_request()
	var targets: Array[GameObjectHandle] = request.get_target_handles()
	if apply_to_owner:
		targets = [execution.get_grant().get_owner_handle()]
	if targets.is_empty():
		return GameCommandResult.rejected_permanent(&"missing_targets", "Apply-effect operation has no targets.")
	for target_handle: GameObjectHandle in targets:
		if target_handle == null or not target_handle.is_resolved():
			return GameCommandResult.invalid_target()
		var target_context: GameObjectContext = target_handle.get_context()
		if target_context == null:
			return GameCommandResult.invalid_target()
		var effects: GameEffects = target_context.get_capability(GameCapabilityIds.EFFECTS_RECEIVER) as GameEffects
		if effects == null:
			return GameCommandResult.missing_capability(GameCapabilityIds.EFFECTS_RECEIVER)
		var result: GameCommandResult = effects.apply_effect(effect_definition, execution.get_grant().get_owner_handle(), request.get_requester_handle(), execution.get_execution_context())
		if not result.is_success():
			return result
	return GameCommandResult.success_changed(&"ability_effects_applied")

## Returns whether a valid effect definition is assigned.
func is_valid() -> bool:
	return effect_definition != null and effect_definition.is_valid()
