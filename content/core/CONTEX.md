# Context: `content/core/`

## Purpose
Universal Game Capability Architecture runtime contracts and systems.

## Architecture
- Godot scenes and Nodes provide composition.
- `Resource` objects are immutable definitions.
- Lightweight `RefCounted` objects hold runtime state.
- Features communicate through capabilities, commands, queries, events, handles, and explicit ports.

## Rules
- No dependencies on concrete entities, props, UI, or external addons.
- No sibling-to-sibling gameplay calls or `get_parent().foo()` dependencies.
- Public and virtual APIs require `##` documentation comments.
- Keep scripts strictly typed and in thematic subfolders.
