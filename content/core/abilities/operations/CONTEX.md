# Context: `content/core/abilities/operations/`

## Purpose
Small composable operations executed by ability executions.

## Key classes
- `GameAbilityOperation` is the extensible operation contract.
- `GameAbilityApplyEffectOperation` delegates effect application through capabilities.

## Rules
- Operations receive prepared execution data and explicit ports.
- Do not search the SceneTree or duplicate cost/cooldown pipelines.
- Child work must preserve execution context and queue semantics.
