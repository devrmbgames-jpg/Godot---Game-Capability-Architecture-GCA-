# Context: `content/core/diagnostics/`

## Purpose
Structured runtime diagnostics, recent command/event/operation traces, and debug snapshots.

## Rules
- Gameplay rejection is data, not necessarily an engine error.
- Configuration errors use higher severity and stable codes.
- Keep bounded histories to avoid unbounded runtime memory.
- Trace handles, IDs, and execution contexts rather than relying on Node names.
