# Context: `content/core/interaction/reactions/`

## Purpose
Data-driven target-local mappings from semantic intents to owned abilities.

## Rules
- Reactions map `intent_id` to target-local `ability_id`.
- Default interaction considers only `default_candidate` reactions.
- Ability requirements/cooldowns/tags decide whether a reaction is currently available.
- Callers see semantic offers and never need the target-local ability implementation.
