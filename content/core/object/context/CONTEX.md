# Context: `content/core/object/context/`

## Purpose
Restricted dependency container passed to initialized features.

## Provides
Kernel/root access, identity/handle, capability queries, tag queries, command/query dispatch, execution queue, diagnostics, explicit world ports, and runtime flags.

## Rules
- Do not turn context into an unrestricted global service locator.
- Add ports only through architectural review.
- Root access is for the object's own presentation/physics, not sibling feature discovery.
