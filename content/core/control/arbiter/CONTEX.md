# Context: `content/core/control/arbiter/`

## Purpose
Registers control sources and arbitrates channel ownership, priority, preemption, and restoration.

## Rules
- Arbiter decides ownership but does not execute gameplay actions.
- Temporary overrides restore valid previous owners deterministically.
- Source removal releases all owned and queued channels safely.
