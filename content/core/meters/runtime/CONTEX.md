# Context: `content/core/meters/runtime/`

## Purpose
Per-owner meter values and the `GameMeters` feature API for current/maximum changes and snapshots.

## Rules
- All mutations return structured previous/current/delta data.
- Resolve attribute-backed maxima through cached capabilities.
- Keep event ordering deterministic and avoid exposing mutable internal maps.
