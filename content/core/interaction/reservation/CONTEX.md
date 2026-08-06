# Context: `content/core/interaction/reservation/`

## Purpose
Source-owned reservation records that prevent incompatible simultaneous interactions.

## Rules
- Reservations use source/target handles, offer ID, priority, expiration, and execution root.
- Cleanup occurs on completion, cancellation, invalidation, timeout, unload, or policy-defined death/disable.
- Releasing one reservation must not affect unrelated owners.
