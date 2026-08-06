# Context: `content/core/control/intents/`

## Purpose
Normalized short-lived control intent data shared by all source types.

## Rules
- Intents carry source, owner, channel, execution context, payload, and consume policy.
- Keep intent creation independent from concrete motor or ability implementations.
- One-shot query-like accessors must not hide gameplay mutations.
