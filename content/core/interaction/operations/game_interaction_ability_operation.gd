@tool
extends GameAbilityOperation
## Generic ability operation for "interact with something".
##
## Uses the first explicit ability target when present; otherwise uses the current
## GameInteractionSource focus. Optional semantic intent comes from activation payload.
class_name GameInteractionAbilityOperation

# ====== PUBLIC ========
## Converts this source-owned ability execution into one semantic interaction request.
func execute(
	abilities: GameAbilities,
	execution: GameAbilityExecution
) -> GameCommandResult:
	if abilities == null or execution == null or execution.get_request() == null:
		return GameCommandResult.configuration_error(
			&"interaction_execution_missing",
			"Interaction ability execution is incomplete."
		)

	var ability_request: GameAbilityActivationRequest = execution.get_request()
	var owner_handle: GameObjectHandle = ability_request.get_owner_handle()
	if owner_handle == null or not owner_handle.is_resolved():
		return GameCommandResult.invalid_target(
			"Interaction ability owner is unresolved."
		)

	var owner_context: GameObjectContext = owner_handle.get_context()
	if owner_context == null:
		return GameCommandResult.invalid_target(
			"Interaction ability owner context is unresolved."
		)

	var interaction_source: GameInteractionSource = owner_context.get_capability(
		GameCapabilityIds.INTERACTION_SOURCE
	) as GameInteractionSource
	if interaction_source == null:
		return GameCommandResult.missing_capability(
			GameCapabilityIds.INTERACTION_SOURCE
		)

	var activation_payload: Dictionary = ability_request.get_activation_payload()
	var intent_id: StringName = StringName(
		activation_payload.get(GameInteractionRequest.ACTIVATION_INTENT_KEY, &"")
	)
	var interaction_payload_value: Variant = activation_payload.get(
		GameInteractionRequest.ACTIVATION_PAYLOAD_KEY,
		{}
	)
	var interaction_payload: Dictionary = {}
	if interaction_payload_value is Dictionary:
		interaction_payload = (
			interaction_payload_value as Dictionary
		).duplicate(true)

	var targets: Array[GameObjectHandle] = ability_request.get_target_handles()
	if not targets.is_empty():
		return interaction_source.activate_target(
			targets[0],
			intent_id,
			execution.get_execution_context(),
			interaction_payload
		)

	return interaction_source.activate_focused(
		intent_id,
		execution.get_execution_context(),
		interaction_payload
	)

func is_valid() -> bool:
	return true
