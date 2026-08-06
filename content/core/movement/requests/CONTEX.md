# Context: `content/core/movement/requests/`

## Purpose
Normalized movement requests carrying direction, magnitude, facing, target, mode, and execution ownership.

## Rules
- Requests are motor-agnostic data.
- Validate ranges and required target data before execution.
- Preserve requester and execution context for diagnostics and cancellation.
