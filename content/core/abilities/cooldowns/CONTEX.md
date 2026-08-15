# Context: `content/core/abilities/cooldowns/`

## Purpose
Runtime cooldown state shared by ability grants and activation queries.

## Rules
- Cooldown starts only at the configured commit phase.
- Persist stable keys and remaining time, never transient handles.
- Keep shared-group behavior outside immutable definitions' runtime state.
