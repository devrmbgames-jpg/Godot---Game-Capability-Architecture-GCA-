# Context: `content/core/execution/queue/`

## Purpose
Deterministic queued operations with root cancellation, depth/budget limits, repeat guards, and explicit error policy.

## Rules
- Child operations enqueue instead of recursing immediately.
- Guard keys include operation type, source definition, target, and trigger.
- Cancellation cleans owned queued work without corrupting other roots.
- Keep operation histories bounded and diagnostics structured.
