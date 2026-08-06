# Context: `content/core/object/`

## Purpose
Local game-object foundation: kernel composition root, feature lifecycle, context injection, identity, and safe handles.

## Rules
- One active kernel coordinates direct child features.
- The root remains a suitable native Godot node type.
- Features depend on capabilities and context, not sibling lookup.
- Identity is stable and handles use weak runtime references.
