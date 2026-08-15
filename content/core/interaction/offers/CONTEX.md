# Context: `content/core/interaction/offers/`

## Purpose
Runtime descriptions of currently available interaction actions.

## Rules
- Offers carry target handles, semantic verb/offer IDs, requirements, priority, reservation, and execution data.
- Treat offers as short-lived snapshots and revalidate them before execution.
- UI metadata does not own gameplay progress or state.
