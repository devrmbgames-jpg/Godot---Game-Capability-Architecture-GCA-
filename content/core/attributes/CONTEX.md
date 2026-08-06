# Context: `content/core/attributes/`

## Purpose
Data-driven modifiable numeric values with immutable definitions, runtime values, and source-owned modifiers.

## Invariant
Final value uses `(base + add) * (1.0 + increase)` before definition clamp policy.

## Rules
- Current resource amounts such as health belong in meters, not attributes.
- Modifiers are removed by handles or ownership, never reverse arithmetic.
- Keep deterministic modifier diagnostics and transaction batching.
