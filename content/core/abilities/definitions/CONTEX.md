# Context: `content/core/abilities/definitions/`

## Purpose
Immutable resource definitions for data-driven abilities.

## Rules
- Definitions contain configuration only; grant, cooldown, target, and phase state are runtime concerns.
- Required owner behavior is expressed through capabilities, tags, queries, and ports.
- New exported IDs and policies require validation and schema-version review.
