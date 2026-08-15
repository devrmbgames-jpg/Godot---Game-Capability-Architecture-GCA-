# Context: `content/core/interaction/`

## Purpose
Semantic interaction requests, focus/query, target-local reactions, ability routing, and reservations.

## Rules
- Sources express only interaction intent; they never inspect target classes or call target gameplay methods.
- Targets map semantic intents to their own local abilities through `GameInteractionReaction`.
- Empty intent means contextual default interaction; explicit intent such as `open` never falls through to another semantic action such as `close`.
- Runtime offers are derived from side-effect-free ability availability queries.
- Player and AI use the same request/offer contracts.
- Reservations have explicit ownership and cleanup.
