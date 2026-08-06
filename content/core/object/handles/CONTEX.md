# Context: `content/core/object/handles/`

## Purpose
Stable object references that survive runtime invalidation and future world unload/load cycles.

## Rules
- Stable identity does not depend on `NodePath`.
- Runtime references are weak and state-checked.
- World resolver may re-resolve known handles without changing callers.
- Persistent data stores stable IDs, not transient runtime instance IDs alone.
