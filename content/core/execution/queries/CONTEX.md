# Context: `content/core/execution/queries/`

## Purpose
Read-only query envelopes and typed `GameQueryResult` outcomes.

## Rules
- Queries never spend resources, start cooldowns, or create gameplay executions.
- Distinguish not-found, failure, invalid target, missing capability, and not-handled states.
- Query targets use handles and route through the kernel capability map.
