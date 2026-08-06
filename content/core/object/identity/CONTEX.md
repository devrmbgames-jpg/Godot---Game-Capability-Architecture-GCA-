# Context: `content/core/object/identity/`

## Purpose
Stable object identity feature and runtime handle preparation.

## Rules
- Placed/persistent objects require unique stable IDs.
- Runtime-generated IDs are explicit and normally session-scoped unless a world allocator upgrades them.
- Duplicate IDs produce editor/runtime configuration warnings.
- Invalidate handles during shutdown or despawn.
