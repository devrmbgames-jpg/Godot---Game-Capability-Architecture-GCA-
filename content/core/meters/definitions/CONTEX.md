# Context: `content/core/meters/definitions/`

## Purpose
Immutable meter configuration: IDs, initial policy, maximum source, thresholds, and save hints.

## Rules
- Maximum source is explicit: constant or attribute ID.
- Definitions never contain per-owner current values.
- Validate maximum/minimum relationships and referenced attributes.
