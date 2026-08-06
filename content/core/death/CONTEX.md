# Context: `content/core/death/`

## Purpose
Gameplay death-state policy driven by meter depletion and tag ownership.

## Rules
- Death is a state transition, not automatic `queue_free()`.
- Prevent duplicate death transitions until an explicit revive/reset.
- Reactions such as explosion, loot, ragdoll, or despawn remain separate operations/features.
