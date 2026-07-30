# Command, event and query contracts

## Command

A `GameCommand` is an addressed intent to mutate state. It contains sender, target, execution context, payload, flags, correlation ID and an optional required capability. Dispatch returns `GameCommandResult`; callers never infer outcome from a boolean.

## Event

A `GameLocalEvent` is a fact that already happened. A feature emits it upward; the kernel assigns a sequence and calls active children in stable initialization order. Events are not used as downward commands.

## Query

A `GameQuery` reads state without side effects. `GameQueryResult` distinguishes found, not found, invalid target, missing capability and unhandled query.

## Cross-object routing

A command/query may resolve another local object through `GameObjectHandle`. The handle uses weak references and becomes safely unresolved after shutdown. Stage 5 may replace the local resolver behavior without changing this public contract.
