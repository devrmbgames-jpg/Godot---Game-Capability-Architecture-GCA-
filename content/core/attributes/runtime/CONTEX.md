# Context: `content/core/attributes/runtime/`

## Purpose
Per-owner attribute values and the `GameAttributes` feature API.

## Rules
- External systems receive query/mutation methods, not mutable collection access.
- Recalculate and emit coherent changes through transactions.
- Keep snapshots keyed by stable attribute IDs.
