# Context: `content/core/interaction/offers/`

## Purpose
Runtime semantic interaction descriptions exposed to UI, AI, and control selection.

## Rules
- Offers describe `offer_id`, semantic `intent_id`, verb, priority, reservation/hold policy, and metadata.
- Offers do not own gameplay execution; target-local ability routing belongs to reactions/targets.
- Offers are runtime views for one concrete target handle.
- UI/AI may select an exact offer without learning the target's ability implementation.
