# Context: `content/core/object/feature/`

## Purpose
Minimal infrastructure base class for active object components and their lifecycle hooks.

## Lifecycle
Discovered → Registered → Resolved → Initialized → Activated → Deactivated → Shutdown.

## Rules
- Hooks remain domain-neutral and idempotent where defined.
- Required dependency loss follows explicit policy.
- Features publish upward through events/signals and never directly call siblings.
