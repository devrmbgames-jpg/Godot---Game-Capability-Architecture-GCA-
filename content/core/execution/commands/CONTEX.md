# Context: `content/core/execution/commands/`

## Purpose
Immutable addressed command envelopes carrying sender, target, capability requirement, payload, and execution context.

## Rules
- Commands are intentions to change state, not broadcasts.
- Validate target handles, command IDs, and execution contexts before routing.
- Typed domain wrappers may be added without bypassing the kernel dispatcher.
