@tool
extends GameFeature
## Feature that exposes and executes semantic interaction reactions.
##
## Reactions map source intent to target-local abilities. Available runtime offers are
## derived from side-effect-free local ability queries, so target state/requirements stay
## authoritative and callers never inspect target classes or methods.
class_name GameInteractionTarget

# ======== EXPORT =========
@export var reactions: Array[GameInteractionReaction] = []
@export_range(0.05, 60.0, 0.05) var reservation_timeout: float = 5.0

# ======== PRIVATE VAR ======
var _abilities: GameAbilities = null
var _reservation: GameInteractionReservation = null
var _reservation_counter: int = 0

# ======= OVERRIDE =======
## Configures target/reservation capabilities and local ability dependency.
func _init() -> void:
	feature_id = &"object.interaction_target"
	if provided_capabilities.is_empty():
		for capability_id: StringName in [
			GameCapabilityIds.INTERACTION_TARGET,
			GameCapabilityIds.INTERACTION_RESERVABLE,
		]:
			var spec := GameCapabilitySpec.new()
			spec.capability_id = capability_id
			provided_capabilities.append(spec)
	if required_dependencies.is_empty():
		var ability_dependency := GameCapabilityDependency.new()
		ability_dependency.capability_id = GameCapabilityIds.ABILITIES_ACTIVATE
		required_dependencies.append(ability_dependency)

## Returns editor warnings for invalid/duplicate reactions or reservation timeout.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = super()
	var offer_ids: Dictionary = {}
	for reaction: GameInteractionReaction in reactions:
		if reaction == null or not reaction.is_valid():
			warnings.append("GameInteractionTarget contains an invalid reaction.")
			continue
		if offer_ids.has(reaction.offer_id):
			warnings.append("Duplicate interaction offer ID '%s'." % reaction.offer_id)
		else:
			offer_ids[reaction.offer_id] = true
	if reservation_timeout <= 0.0:
		warnings.append("Reservation timeout must be greater than zero.")
	return warnings

## Resolves the target-local ability owner used for reaction execution.
func on_game_initialize() -> GameCommandResult:
	_abilities = get_dependency(GameCapabilityIds.ABILITIES_ACTIVATE) as GameAbilities
	if _abilities == null:
		return GameCommandResult.configuration_error(
			&"interaction_target_abilities_missing",
			"Interaction target requires local GameAbilities."
		)
	return GameCommandResult.success_changed(&"interaction_target_initialized")

## Releases reservation and dependency state during shutdown.
func on_game_shutdown() -> void:
	if _reservation != null:
		_reservation.release()
	_reservation = null
	_abilities = null

# ====== HELPERS ========
func _same_object_handle(a: GameObjectHandle, b: GameObjectHandle) -> bool:
	if a == null or b == null:
		return false
	if a.get_stable_id() != b.get_stable_id():
		return false
	var a_runtime_id: int = a.get_runtime_instance_id()
	var b_runtime_id: int = b.get_runtime_instance_id()
	return a_runtime_id <= 0 or b_runtime_id <= 0 or a_runtime_id == b_runtime_id

func _sorted_reactions() -> Array[GameInteractionReaction]:
	var result: Array[GameInteractionReaction] = []
	for reaction: GameInteractionReaction in reactions:
		if reaction != null and reaction.is_valid():
			result.append(reaction)
	result.sort_custom(func(a: GameInteractionReaction, b: GameInteractionReaction) -> bool:
		if a.priority != b.priority:
			return a.priority > b.priority
		return String(a.offer_id) < String(b.offer_id)
	)
	return result

func _candidate_reactions(request: GameInteractionRequest) -> Array[GameInteractionReaction]:
	var result: Array[GameInteractionReaction] = []
	for reaction: GameInteractionReaction in _sorted_reactions():
		if not request.get_offer_id().is_empty():
			if reaction.offer_id == request.get_offer_id():
				result.append(reaction)
			continue
		if not request.get_intent_id().is_empty():
			if reaction.intent_id == request.get_intent_id():
				result.append(reaction)
			continue
		if reaction.default_candidate:
			result.append(reaction)
	return result

func _build_ability_request(
	reaction: GameInteractionReaction,
	request: GameInteractionRequest
) -> GameAbilityActivationRequest:
	var owner_handle: GameObjectHandle = get_context().get_object_handle()
	var ability_request := GameAbilityActivationRequest.new(
		reaction.ability_id,
		owner_handle,
		request.get_execution_context(),
		request.get_source_handle()
	)
	if request.get_source_handle() != null:
		ability_request.set_targets([request.get_source_handle()])
	ability_request.set_activation_payload({
		&"interaction_intent_id": reaction.intent_id,
		&"interaction_offer_id": reaction.offer_id,
		&"interaction_payload": request.get_payload(),
	})
	return ability_request

func _execute_reaction(
	reaction: GameInteractionReaction,
	request: GameInteractionRequest
) -> GameCommandResult:
	if reaction.reservation_required:
		var reservation_result: GameCommandResult = reserve(
			request.get_source_handle(),
			reaction.offer_id,
			reaction.priority,
			request.get_execution_context()
		)
		if not reservation_result.is_success():
			return reservation_result

	var result: GameCommandResult = _abilities.activate(
		_build_ability_request(reaction, request)
	)

	if _reservation != null:
		release_reservation(_reservation.get_handle_id())
	return result

# ====== PUBLIC ========
## Returns currently executable semantic offers for one source.
func query_offers(
	source_handle: GameObjectHandle,
	execution_context: GameExecutionContext
) -> Array[GameInteractionOffer]:
	var result: Array[GameInteractionOffer] = []
	if _abilities == null or source_handle == null or execution_context == null:
		return result

	var target_handle: GameObjectHandle = get_context().get_object_handle()
	for reaction: GameInteractionReaction in _sorted_reactions():
		var request := GameInteractionRequest.new(
			source_handle,
			target_handle,
			reaction.intent_id,
			execution_context
		)
		request.set_offer_id(reaction.offer_id)
		var query_result: GameAbilityActivationQueryResult = _abilities.query_activation(
			_build_ability_request(reaction, request)
		)
		if not query_result.is_available():
			continue
		var offer: GameInteractionOffer = reaction.build_offer(target_handle)
		if offer != null:
			result.append(offer)
	return result

## Resolves exact offer, semantic intent, or default reaction and executes target-local ability.
func activate_interaction(request: GameInteractionRequest) -> GameCommandResult:
	if request == null or not request.is_valid():
		return GameCommandResult.configuration_error(
			&"invalid_interaction_request",
			"Interaction request is incomplete."
		)
	var owner_handle: GameObjectHandle = get_context().get_object_handle()
	if not _same_object_handle(request.get_target_handle(), owner_handle):
		return GameCommandResult.invalid_target(
			"Interaction request target does not match this interaction target."
		)
	if _abilities == null:
		return GameCommandResult.missing_capability(GameCapabilityIds.ABILITIES_ACTIVATE)

	var candidates: Array[GameInteractionReaction] = _candidate_reactions(request)
	if candidates.is_empty():
		if not request.get_offer_id().is_empty():
			return GameCommandResult.rejected_permanent(
				&"interaction_offer_unsupported",
				"Target does not provide interaction offer '%s'." % request.get_offer_id()
			)
		if not request.get_intent_id().is_empty():
			return GameCommandResult.rejected_permanent(
				&"interaction_intent_unsupported",
				"Target does not support interaction intent '%s'." % request.get_intent_id()
			)
		return GameCommandResult.rejected_temporary(
			&"no_interaction_available",
			"Target has no default interaction reactions."
		)

	for reaction: GameInteractionReaction in candidates:
		var query_result: GameAbilityActivationQueryResult = _abilities.query_activation(
			_build_ability_request(reaction, request)
		)
		if query_result.is_available():
			return _execute_reaction(reaction, request)

	if not request.get_offer_id().is_empty() or not request.get_intent_id().is_empty():
		return _abilities.activate(_build_ability_request(candidates[0], request))

	return GameCommandResult.rejected_temporary(
		&"no_interaction_available",
		"No default interaction reaction is currently executable."
	)

## Acquires or preempts the current reservation according to priority and timeout.
func reserve(
	source_handle: GameObjectHandle,
	offer_id: StringName,
	priority: int,
	execution_context: GameExecutionContext,
	simulation_time: float = 0.0
) -> GameCommandResult:
	if source_handle == null or execution_context == null:
		return GameCommandResult.configuration_error(
			&"invalid_reservation_request",
			"Reservation request is incomplete."
		)
	if (
		_reservation != null
		and _reservation.is_active()
		and not _reservation.is_expired(simulation_time)
	):
		if priority <= _reservation.get_priority():
			return GameCommandResult.rejected_temporary(
				&"interaction_occupied",
				"Interaction target is reserved."
			)
		_reservation.release()
	_reservation_counter += 1
	_reservation = GameInteractionReservation.new(
		_reservation_counter,
		source_handle,
		get_context().get_object_handle(),
		offer_id,
		priority,
		simulation_time + reservation_timeout,
		execution_context.get_root_operation_id()
	)
	return GameCommandResult.success_changed(&"interaction_reserved", _reservation)

## Releases the current reservation only when [param handle_id] matches it.
func release_reservation(handle_id: int) -> GameCommandResult:
	if _reservation == null or _reservation.get_handle_id() != handle_id:
		return GameCommandResult.success_unchanged(&"reservation_not_found")
	_reservation.release()
	_reservation = null
	return GameCommandResult.success_changed(&"reservation_released")

## Returns the current reservation record, or [code]null[/code].
func get_active_reservation() -> GameInteractionReservation:
	return _reservation

## Returns reaction count and current reservation diagnostics.
func get_debug_snapshot() -> Dictionary:
	return {
		"reactions": reactions.size(),
		"reservation": (
			_reservation.to_dictionary() if _reservation != null else {}
		),
	}
