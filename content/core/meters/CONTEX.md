# Context: `content/core/meters/`

## Purpose
Current resource quantities such as health, stamina, mana, integrity, and progress.

## Rules
- Meter current values are separate from modifiable maximum attributes.
- Clamp and maximum-change policies are explicit.
- Depletion/fill events fire on threshold crossings, not every repeated below/above update.
- Snapshots use stable meter IDs.
