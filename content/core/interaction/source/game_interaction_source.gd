@tool
extends GameFeature
## Feature that queries, focuses, selects, and executes interaction offers.
##
## Resolves targets by handle, revalidates offers before execution, owns temporary
## reservations, and delegates gameplay to the ability system.
class_name GameInteractionSource

## Emitted when the focused target or selected offer changes.
signal focus_changed(target_handle: GameObjectHandle, offer_id: StringName)
## Emitted after a selected interaction completes successfully.
signal interaction_completed(target_handle: GameObjectHandle, offer_id: StringName)

# ======== PRIVATE VAR ======
var _abilities: GameAbilities = null
var _focus_target: GameObjectHandle = null
var _focused_offers: Array[GameInteractionOffer] = []
var _selected_offer_id: StringName = &""
var _reservation: GameInteractionReservation = null

# ======= OVERRIDE =======
## Configures interaction source/query capabilities and optional ability dependency.
func _init() -> void:
	feature_id = &"object.interaction_source"
	if provided_capabilities.is_empty():
		for capability_id: StringName in [GameCapabilityIds.INTERACTION_SOURCE, GameCapabilityIds.INTERACTION_QUERY]:
			var spec := GameCapabilitySpec.new()
			spec.capability_id = capability_id
			provided_capabilities.append(spec)
	if optional_dependencies.is_empty():
		var dependency := GameCapabilityDependency.new()
		dependency.capability_id = GameCapabilityIds.ABILITIES_ACTIVATE
		dependency.required = false
		optional_dependencies.append(dependency)

## Resolves the optional ability activation capability.
func on_game_initialize() -> GameCommandResult:
	_abilities = get_dependency(GameCapabilityIds.ABILITIES_ACTIVATE) as GameAbilities
	return GameCommandResult.success_changed(&"interaction_source_initialized")

## Cancels reservations and clears focus and dependency state.
func on_game_shutdown() -> void:
	cancel_interaction(&"shutdown")
	_focus_target = null; _focused_offers.clear(); _abilities = null

# ====== HELPERS ========
func _get_target_feature(target_handle: GameObjectHandle) -> GameInteractionTarget:
	if target_handle == null or not target_handle.is_resolved(): return null
	var context: GameObjectContext = target_handle.get_context()
	return context.get_capability(GameCapabilityIds.INTERACTION_TARGET) as GameInteractionTarget if context != null else null

func _find_offer(offer_id: StringName) -> GameInteractionOffer:
	for offer: GameInteractionOffer in _focused_offers:
		if offer.get_offer_id() == offer_id: return offer
	return null

# ====== PUBLIC ========
## Queries currently valid offers from [param target_handle].
func query_target(target_handle: GameObjectHandle, execution_context: GameExecutionContext) -> Array[GameInteractionOffer]:
	var target: GameInteractionTarget = _get_target_feature(target_handle)
	if target == null: return []
	return target.query_offers(get_context().get_object_handle(), execution_context)

## Focuses a target, caches its sorted offers, and selects the first offer.
func set_focus(target_handle: GameObjectHandle, execution_context: GameExecutionContext) -> GameCommandResult:
	var offers: Array[GameInteractionOffer] = query_target(target_handle, execution_context)
	if offers.is_empty(): return GameCommandResult.rejected_temporary(&"no_interaction_offers", "Target has no available interaction offers.")
	_focus_target = target_handle
	_focused_offers = offers
	_selected_offer_id = offers[0].get_offer_id()
	focus_changed.emit(_focus_target, _selected_offer_id)
	return GameCommandResult.success_changed(&"interaction_focus_set", offers)

## Selects one offer from the current focused offer set.
func select_offer(offer_id: StringName) -> GameCommandResult:
	if _find_offer(offer_id) == null: return GameCommandResult.rejected_permanent(&"unknown_interaction_offer", "Offer is not available in current focus.")
	_selected_offer_id = offer_id
	focus_changed.emit(_focus_target, _selected_offer_id)
	return GameCommandResult.success_changed(&"interaction_offer_selected")

## Revalidates and executes the selected offer, acquiring reservation when required.
func execute_selected(execution_context: GameExecutionContext) -> GameCommandResult:
	if _focus_target == null: return GameCommandResult.invalid_target("Interaction focus is empty.")
	var target: GameInteractionTarget = _get_target_feature(_focus_target)
	if target == null: return GameCommandResult.missing_capability(GameCapabilityIds.INTERACTION_TARGET)
	_focused_offers = target.query_offers(get_context().get_object_handle(), execution_context)
	var offer: GameInteractionOffer = _find_offer(_selected_offer_id)
	if offer == null: return GameCommandResult.rejected_temporary(&"interaction_offer_invalidated", "Selected interaction offer is no longer valid.")
	if offer.requires_reservation():
		var reservation_result: GameCommandResult = target.reserve(get_context().get_object_handle(), offer.get_offer_id(), offer.get_priority(), execution_context)
		if not reservation_result.is_success(): return reservation_result
		_reservation = reservation_result.get_payload() as GameInteractionReservation
	var result: GameCommandResult
	if not offer.get_ability_id().is_empty():
		if _abilities == null: result = GameCommandResult.missing_capability(GameCapabilityIds.ABILITIES_ACTIVATE)
		else:
			var request := GameAbilityActivationRequest.new(offer.get_ability_id(), get_context().get_object_handle(), execution_context, get_context().get_object_handle())
			request.set_targets([_focus_target])
			request.set_activation_payload({"interaction_offer_id": offer.get_offer_id(), "verb_id": offer.get_verb_id()})
			result = _abilities.activate(request)
	else:
		result = GameCommandResult.rejected_permanent(&"interaction_command_not_implemented", "Command-backed offers require a registered command definition.")
	if _reservation != null:
		target.release_reservation(_reservation.get_handle_id())
		_reservation = null
	if result.is_success(): interaction_completed.emit(_focus_target, offer.get_offer_id())
	return result

## Routes normalized interaction intents to focus, selection, execution, or cancellation.
func handle_interaction_intent(intent: GameControlIntent) -> GameCommandResult:
	var payload: Dictionary = intent.get_payload()
	match intent.get_intent_type():
		&"interaction.focus": return set_focus(payload.get("target_handle") as GameObjectHandle, intent.get_execution_context())
		&"interaction.select": return select_offer(payload.get("offer_id", &""))
		&"interaction.execute": return execute_selected(intent.get_execution_context())
		&"interaction.cancel": return cancel_interaction(&"control_cancelled")
		_: return GameCommandResult.rejected_permanent(&"unsupported_interaction_intent", "Unsupported interaction intent.")

## Releases the current reservation without clearing the focused target.
func cancel_interaction(reason: StringName = &"cancelled") -> GameCommandResult:
	if _reservation != null and _focus_target != null:
		var target: GameInteractionTarget = _get_target_feature(_focus_target)
		if target != null: target.release_reservation(_reservation.get_handle_id())
	_reservation = null
	return GameCommandResult.success_changed(reason)

## Returns focus, selected offer, current offers, and reservation diagnostics.
func get_debug_snapshot() -> Dictionary:
	var offers: Array[Dictionary] = []
	for offer: GameInteractionOffer in _focused_offers: offers.append(offer.to_dictionary())
	return {"focus": _focus_target.to_dictionary() if _focus_target != null else {}, "selected_offer_id": _selected_offer_id, "offers": offers, "reservation": _reservation.to_dictionary() if _reservation != null else {}}
