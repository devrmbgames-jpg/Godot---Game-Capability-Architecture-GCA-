# Context: `content/core/interaction/`

## Purpose
Runtime interaction sources, targets, offers, focus/revalidation, execution routing, and reservations.

## Rules
- Targets expose offers based on current state; selected offers revalidate before execution.
- Player and AI use the same offer contract.
- Actual mechanics delegate to abilities or commands, not direct target method calls.
- Reservations have explicit ownership and cleanup.
