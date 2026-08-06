# Context: `content/core/effects/runtime/`

## Purpose
`GameActiveEffect` state and the `GameEffects` feature that applies, advances, stacks, queries, and removes effects.

## Rules
- Prepare required mutations before committing an application.
- Avoid modifying active collections during iteration; defer child work through the queue.
- Preserve source, instigator, target, snapshot values, and execution root IDs.
