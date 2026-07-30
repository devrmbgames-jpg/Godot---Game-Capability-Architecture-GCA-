# Foundation lifecycle

## Kernel lifecycle

`Uninitialized → Discovering → Validating → Initializing → Activated → Deactivated → Shutdown`

A configuration failure moves the kernel to `ConfigurationError`; no gameplay feature is activated after a required dependency failure.

## Feature lifecycle

1. `Discovered`: direct child found by the kernel.
2. `Registered`: provided capabilities are registered.
3. `Resolved`: required dependencies are validated and cached.
4. `Initialized`: context is injected and local state is prepared.
5. `Activated`: gameplay commands and events are accepted.
6. `Deactivated`: gameplay is stopped while state remains readable.
7. `Shutdown`: references and registrations are released.

Shutdown is performed in reverse dependency order. Repeated shutdown is safe.

## Dynamic composition

Runtime registration and removal are routed through the kernel. If requested during event delivery or operation execution, the mutation is queued until the safe phase. Removing a required capability deactivates dependants according to their loss policy.
