# Context: `content/core/effects/`

## Purpose
Gameplay effect definitions, active runtime instances, stacking, periodic advancement, and owned mutations.

## Rules
- Definitions are immutable; active effects hold owner-specific state.
- One centralized feature advances effects instead of one Node per effect.
- Effect removal cleans only its own modifier and tag handles.
- Child operations preserve the execution chain and queue guards.
