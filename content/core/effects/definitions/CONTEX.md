# Context: `content/core/effects/definitions/`

## Purpose
Immutable `GameEffectDefinition` configuration for duration, period, stacking, tags, attribute modifiers, and meter operations.

## Rules
- Explicit policies distinguish instant, duration, and infinite effects.
- Validate IDs, periods, durations, stack limits, and operation targets.
- Do not store remaining time, handles, stacks, or owner state in definitions.
