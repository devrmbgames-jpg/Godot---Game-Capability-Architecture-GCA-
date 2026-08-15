# Context: `content/core/abilities/activation/`

## Purpose
Side-effect-free activation query results and explicit activation request data.

## Key classes
- `GameAbilityActivationQueryResult` explains availability and failure details.
- `GameAbilityActivationRequest` carries owner, grant, target, payload, and execution context.

## Rules
- Query construction and evaluation must not spend resources or start cooldowns.
- Requests use handles and normalized target data, not raw SceneTree searches.
