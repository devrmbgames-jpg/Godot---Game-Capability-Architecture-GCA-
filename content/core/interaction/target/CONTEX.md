# Context: `content/core/interaction/target/`

## Purpose
Feature contract for objects that expose semantic interaction offers and execute target-local reactions.

## Rules
- Target reactions map semantic intents to local abilities.
- Offers reflect current target ability availability and source context.
- Default interaction selects the highest-priority available default candidate.
- Explicit intent only considers reactions for that intent and never toggles to another intent.
- Targets execute their own abilities; controllers/sources do not know target implementation.
