# Context: `content/core/object/kernel/`

## Purpose
`GameObjectKernel` is the local composition root and mediator for one game object.

## Responsibilities
Discover direct features, validate composition, register capabilities, resolve dependencies, build context, run lifecycle, route commands/queries/events, process operations, and expose diagnostics.

## Rules
- Keep domain mechanics out of the kernel.
- Never create hidden mandatory features at runtime.
- Mutate feature composition only through safe kernel phases.
- Shutdown in reverse dependency order.
