# Context: `content/core/abilities/`

## Purpose
Data-driven ability ownership, activation, cost, cooldown, execution, cancellation, and operation contracts.

## Model
- `GameAbilityDefinition` is immutable configuration.
- `GameAbilityGrant` is owner/source-specific permission and state.
- `GameAbilityExecution` is one activation lifecycle.
- `GameAbilities` coordinates grants, queries, commits, and active executions.

## Rules
- Ability logic depends on capabilities and ports, never owner classes.
- Activation queries are side-effect free.
- Child abilities and effects use the execution queue.
- Runtime state never belongs in shared definitions.
