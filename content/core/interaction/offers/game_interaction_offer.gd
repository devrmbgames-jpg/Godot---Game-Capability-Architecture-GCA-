extends Resource
## Runtime semantic interaction offered by a target to a source.
##
## Offers describe what the source may attempt (intent/verb/presentation) and never
## expose the target-local ability or implementation used to perform that reaction.
class_name GameInteractionOffer

# ======== PRIVATE VAR ======
var _offer_id: StringName = &""
var _intent_id: StringName = &""
var _verb_id: StringName = &""
var _target_handle: GameObjectHandle = null
var _priority: int = 0
var _reservation_required: bool = false
var _hold_duration: float = 0.0
var _metadata: Dictionary = {}

# ======= OVERRIDE =======
## Creates an offer identified by semantic offer/verb IDs and a target handle.
func _init(
	offer_id: StringName = &"",
	verb_id: StringName = &"",
	target_handle: GameObjectHandle = null
) -> void:
	_offer_id = offer_id
	_verb_id = verb_id
	_target_handle = target_handle

# ====== PUBLIC ========
## Sets the semantic intent represented by this offer.
func set_intent_id(value: StringName) -> void:
	_intent_id = value

## Sets designer sorting priority.
func set_priority(value: int) -> void:
	_priority = value

## Sets whether target reservation is required before execution.
func set_reservation_required(value: bool) -> void:
	_reservation_required = value

## Sets a non-negative hold/channel duration.
func set_hold_duration(value: float) -> void:
	_hold_duration = maxf(value, 0.0)

## Stores a deep copy of presentation and query metadata.
func set_metadata(value: Dictionary) -> void:
	_metadata = value.duplicate(true)

## Returns the target-local offer ID.
func get_offer_id() -> StringName:
	return _offer_id

## Returns the semantic interaction intent.
func get_intent_id() -> StringName:
	return _intent_id

## Returns the semantic verb ID used by UI and AI.
func get_verb_id() -> StringName:
	return _verb_id

## Returns the object providing this offer.
func get_target_handle() -> GameObjectHandle:
	return _target_handle

## Returns designer sorting priority.
func get_priority() -> int:
	return _priority

## Returns whether execution must acquire a reservation.
func requires_reservation() -> bool:
	return _reservation_required

## Returns required hold duration.
func get_hold_duration() -> float:
	return _hold_duration

## Returns a deep copy of presentation/query metadata.
func get_metadata() -> Dictionary:
	return _metadata.duplicate(true)

## Returns whether runtime semantic identity and target are configured.
func is_valid() -> bool:
	return (
		not _offer_id.is_empty()
		and not _intent_id.is_empty()
		and not _verb_id.is_empty()
		and _target_handle != null
	)

## Serializes semantic offer data for UI, AI, and diagnostics.
func to_dictionary() -> Dictionary:
	return {
		"offer_id": _offer_id,
		"intent_id": _intent_id,
		"verb_id": _verb_id,
		"target": (
			_target_handle.to_dictionary() if _target_handle != null else {}
		),
		"priority": _priority,
		"reservation_required": _reservation_required,
		"hold_duration": _hold_duration,
		"metadata": _metadata.duplicate(true),
	}
