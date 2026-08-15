# Context: `content/core/abilities/executions/`

## Purpose
Per-activation ability lifecycle state, target snapshots, owned tags, and operation progress.

## Rules
- Terminal transitions occur once and release execution-owned resources.
- Execution context root/parent identity must be preserved for child work.
- Shared definitions remain immutable.
- Cancellation must clean waits, tags, and owned operations according to policy.
