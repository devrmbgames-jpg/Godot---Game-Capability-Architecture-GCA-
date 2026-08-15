@tool
extends Resource
## Target-local mapping from a semantic interaction intent to one owned ability.
##
## Reactions are data only. The target queries the local ability before exposing the
## reaction as an offer, so requirements/cooldowns/tags remain authoritative.
class_name GameInteractionReaction

# ======== EXPORT =========
@export var offer_id: StringName = &""
@export var intent_id: StringName = &""
@export var verb_id: StringName = &""
@export var ability_id: StringName = &""
@export var priority: int = 0
@export var default_candidate: bool = true
@export var reservation_required: bool = false
@export_range(0.0, 60.0, 0.05) var hold_duration: float = 0.0
@export var metadata: Dictionary = {}

# ====== PUBLIC ========
## Returns whether semantic identity and target-local ability routing are configured.
func is_valid() -> bool:
	return (
		not offer_id.is_empty()
		and not intent_id.is_empty()
		and not verb_id.is_empty()
		and not ability_id.is_empty()
		and hold_duration >= 0.0
	)

## Creates a runtime semantic offer without exposing [member ability_id].
func build_offer(target_handle: GameObjectHandle) -> GameInteractionOffer:
	if target_handle == null or not is_valid():
		return null
	var offer: GameInteractionOffer = GameInteractionOffer.new(
		offer_id,
		verb_id,
		target_handle
	)
	offer.set_intent_id(intent_id)
	offer.set_priority(priority)
	offer.set_reservation_required(reservation_required)
	offer.set_hold_duration(hold_duration)
	offer.set_metadata(metadata)
	return offer
