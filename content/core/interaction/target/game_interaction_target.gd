@tool
extends GameFeature
## Feature that exposes interaction offers and optional exclusive reservation.
##
## Produces deterministic runtime offers, grants reservations by priority, and
## releases owned reservation state during shutdown.
class_name GameInteractionTarget

# ======== EXPORT =========
@export var offer_templates: Array[GameInteractionOffer] = []
@export var reservation_timeout: float = 5.0

# ======== PRIVATE VAR ======
var _reservation: GameInteractionReservation = null
var _reservation_counter: int = 0

# ======= OVERRIDE =======
## Configures interaction target, query, and reservation capabilities.
func _init() -> void:
	feature_id = &"object.interaction_target"
	if provided_capabilities.is_empty():
		for capability_id: StringName in [GameCapabilityIds.INTERACTION_TARGET, GameCapabilityIds.INTERACTION_QUERY, GameCapabilityIds.INTERACTION_RESERVABLE]:
			var spec := GameCapabilitySpec.new()
			spec.capability_id = capability_id
			provided_capabilities.append(spec)

## Returns editor warnings for invalid offers or reservation timeout.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = super()
	for offer: GameInteractionOffer in offer_templates:
		if offer == null or not offer.is_valid(): warnings.append("Interaction target contains an invalid offer template.")
	if reservation_timeout <= 0.0: warnings.append("Reservation timeout must be greater than zero.")
	return warnings

## Releases the current reservation when the target shuts down.
func on_game_shutdown() -> void:
	if _reservation != null: _reservation.release()
	_reservation = null

# ====== PUBLIC ========
## Returns valid offers sorted by descending priority and stable offer ID.
func query_offers(_source_handle: GameObjectHandle, _execution_context: GameExecutionContext) -> Array[GameInteractionOffer]:
	var result: Array[GameInteractionOffer] = []
	for template: GameInteractionOffer in offer_templates:
		if template != null and template.is_valid(): result.append(template)
	result.sort_custom(func(a: GameInteractionOffer, b: GameInteractionOffer) -> bool:
		if a.get_priority() != b.get_priority(): return a.get_priority() > b.get_priority()
		return String(a.get_offer_id()) < String(b.get_offer_id()))
	return result

## Acquires or preempts the current reservation according to priority and timeout.
func reserve(source_handle: GameObjectHandle, offer_id: StringName, priority: int, execution_context: GameExecutionContext, simulation_time: float = 0.0) -> GameCommandResult:
	if source_handle == null or execution_context == null: return GameCommandResult.configuration_error(&"invalid_reservation_request", "Reservation request is incomplete.")
	if _reservation != null and _reservation.is_active() and not _reservation.is_expired(simulation_time):
		if priority <= _reservation.get_priority(): return GameCommandResult.rejected_temporary(&"interaction_occupied", "Interaction target is reserved.")
		_reservation.release()
	_reservation_counter += 1
	_reservation = GameInteractionReservation.new(_reservation_counter, source_handle, get_context().get_object_handle(), offer_id, priority, simulation_time + reservation_timeout, execution_context.get_root_operation_id())
	return GameCommandResult.success_changed(&"interaction_reserved", _reservation)

## Releases the current reservation only when [param handle_id] matches it.
func release_reservation(handle_id: int) -> GameCommandResult:
	if _reservation == null or _reservation.get_handle_id() != handle_id: return GameCommandResult.success_unchanged(&"reservation_not_found")
	_reservation.release(); _reservation = null
	return GameCommandResult.success_changed(&"reservation_released")

## Returns the current reservation record, or [code]null[/code].
func get_active_reservation() -> GameInteractionReservation: return _reservation
## Returns offer count and current reservation diagnostics.
func get_debug_snapshot() -> Dictionary:
	return {"offers": offer_templates.size(), "reservation": _reservation.to_dictionary() if _reservation != null else {}}
