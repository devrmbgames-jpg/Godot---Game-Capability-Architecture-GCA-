# Context: `content/core/execution/events/`

## Purpose
Local completed-fact event envelopes delivered upward to the kernel and then in deterministic feature order.

## Rules
- Event names describe facts that already happened.
- Events carry source and execution context.
- Do not use events as hidden downward commands.
- Avoid direct sibling knowledge in event publishers or consumers.
