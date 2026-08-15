@tool
extends GameFeature
## Feature that queries, focuses, selects, and requests semantic interactions.
##
## Sources express intent only. Targets own reaction resolution and execute their own
## local abilities; source code never checks target classes or calls target gameplay methods.
class_name GameInteractionSource

## Emitted when the focused target or selected offer changes.
signal focus_changed(target_handle: GameObjectHandle, offer_id: StringName)
## Emitted after an interaction request completes successfully.
signal interaction_completed(target_handle: GameObjectHandle, offer_id: StringName)

# ======== PRIVATE VAR ======
var _focus_target: GameObjectHandle = null
var _focused_offers: Array[GameInteractionOffer] = []
var _selected_offer_id: StringName = &""

# ======= OVERRIDE =======
## Configures interaction source/query capabilities.
func _init() -> void:
	feature_id = &"object.interaction_source"
	if provided_capabilities.is_empty():
		for capability_id: StringName in [
			GameCapabilityIds.INTERACTION_SOURCE,
			GameCapabilityIds.INTERACTION_QUERY,
		]:
			var spec := GameCapabilitySpec.new()
			spec.capability_id = capability_id
			provided_capabilities.append(spec)

## Clears focus state during shutdown.
func on_game_shutdown() -> void:
	_focus_target = null
	_focused_offers.clear()
	_selected_offer_id = &""

# ====== HELPERS ========
func _get_target_feature(target_handle: GameObjectHandle) -> GameInteractionTarget:
	if target_handle == null or not target_handle.is_resolved():
		return null
	var context: GameObjectContext = target_handle.get_context()
	if context == null:
		return null
	return context.get_capability(
		GameCapabilityIds.INTERACTION_TARGET
	) as GameInteractionTarget

func _find_offer(offer_id: StringName) -> GameInteractionOffer:
	for offer: GameInteractionOffer in _focused_offers:
		if offer.get_offer_id() == offer_id:
			return offer
	return null

# ====== PUBLIC ========
## Queries currently executable semantic offers from [param target_handle].
func query_target(
	target_handle: GameObjectHandle,
	execution_context: GameExecutionContext
) -> Array[GameInteractionOffer]:
	var target: GameInteractionTarget = _get_target_feature(target_handle)
	if target == null:
		return []
	return target.query_offers(
		get_context().get_object_handle(),
		execution_context
	)

## Focuses a target, caches its sorted offers, and selects the first offer.
func set_focus(
	target_handle: GameObjectHandle,
	execution_context: GameExecutionContext
) -> GameCommandResult:
	var offers: Array[GameInteractionOffer] = query_target(
		target_handle,
		execution_context
	)
	if offers.is_empty():
		return GameCommandResult.rejected_temporary(
			&"no_interaction_offers",
			"Target has no available interaction offers."
		)
	_focus_target = target_handle
	_focused_offers = offers
	_selected_offer_id = offers[0].get_offer_id()
	focus_changed.emit(_focus_target, _selected_offer_id)
	return GameCommandResult.success_changed(&"interaction_focus_set", offers)

## Selects one offer from the current focused offer set.
func select_offer(offer_id: StringName) -> GameCommandResult:
	if _find_offer(offer_id) == null:
		return GameCommandResult.rejected_permanent(
			&"unknown_interaction_offer",
			"Offer is not available in current focus."
		)
	_selected_offer_id = offer_id
	focus_changed.emit(_focus_target, _selected_offer_id)
	return GameCommandResult.success_changed(&"interaction_offer_selected")

## Requests one target interaction without knowing target implementation.
## Empty [param intent_id] and [param offer_id] mean default contextual interaction.
func activate_target(
	target_handle: GameObjectHandle,
	intent_id: StringName,
	execution_context: GameExecutionContext,
	payload: Dictionary = {},
	offer_id: StringName = &""
) -> GameCommandResult:
	var target: GameInteractionTarget = _get_target_feature(target_handle)
	if target == null:
		return GameCommandResult.missing_capability(
			GameCapabilityIds.INTERACTION_TARGET
		)
	var request: GameInteractionRequest = GameInteractionRequest.new(
		get_context().get_object_handle(),
		target_handle,
		intent_id,
		execution_context
	)
	request.set_offer_id(offer_id)
	request.set_payload(payload)
	var result: GameCommandResult = target.activate_interaction(request)
	if result.is_success():
		interaction_completed.emit(target_handle, offer_id)
	return result

## Requests interaction against current focus. Empty intent means target default action.
func activate_focused(
	intent_id: StringName,
	execution_context: GameExecutionContext,
	payload: Dictionary = {}
) -> GameCommandResult:
	if _focus_target == null:
		return GameCommandResult.invalid_target("Interaction focus is empty.")
	return activate_target(
		_focus_target,
		intent_id,
		execution_context,
		payload
	)

## Revalidates and executes the explicitly selected semantic offer.
func execute_selected(execution_context: GameExecutionContext) -> GameCommandResult:
	if _focus_target == null:
		return GameCommandResult.invalid_target("Interaction focus is empty.")
	_focused_offers = query_target(_focus_target, execution_context)
	var offer: GameInteractionOffer = _find_offer(_selected_offer_id)
	if offer == null:
		return GameCommandResult.rejected_temporary(
			&"interaction_offer_invalidated",
			"Selected interaction offer is no longer valid."
		)
	return activate_target(
		_focus_target,
		offer.get_intent_id(),
		execution_context,
		{},
		offer.get_offer_id()
	)

## Routes normalized interaction intents to focus, selection, execution, or cancellation.
func handle_interaction_intent(intent: GameControlIntent) -> GameCommandResult:
	var payload: Dictionary = intent.get_payload()
	match intent.get_intent_type():
		&"interaction.focus":
			return set_focus(
				payload.get("target_handle") as GameObjectHandle,
				intent.get_execution_context()
			)
		&"interaction.select":
			return select_offer(
				StringName(payload.get("offer_id", &""))
			)
		&"interaction.execute":
			var intent_id: StringName = StringName(
				payload.get("intent_id", &"")
			)
			if not intent_id.is_empty():
				var interaction_payload_value: Variant = payload.get(
					"interaction_payload",
					{}
				)
				var interaction_payload: Dictionary = {}
				if interaction_payload_value is Dictionary:
					interaction_payload = (
						interaction_payload_value as Dictionary
					).duplicate(true)
				return activate_focused(
					intent_id,
					intent.get_execution_context(),
					interaction_payload
				)
			return execute_selected(intent.get_execution_context())
		&"interaction.cancel":
			return cancel_interaction(&"control_cancelled")
		_:
			return GameCommandResult.rejected_permanent(
				&"unsupported_interaction_intent",
				"Unsupported interaction intent."
			)

## Clears cached selection while retaining focus identity.
func cancel_interaction(reason: StringName = &"cancelled") -> GameCommandResult:
	_focused_offers.clear()
	_selected_offer_id = &""
	return GameCommandResult.success_changed(reason)

## Returns current focused target.
func get_focus_target() -> GameObjectHandle:
	return _focus_target

## Returns selected runtime offer ID, if any.
func get_selected_offer_id() -> StringName:
	return _selected_offer_id

## Returns focus, selected offer, and current semantic offers for diagnostics.
func get_debug_snapshot() -> Dictionary:
	var offers: Array[Dictionary] = []
	for offer: GameInteractionOffer in _focused_offers:
		offers.append(offer.to_dictionary())
	return {
		"focus": _focus_target.to_dictionary() if _focus_target != null else {},
		"selected_offer_id": _selected_offer_id,
		"offers": offers,
	}
