# Context: `addons/gca_data_studio/`

## Purpose
Godot editor-only tooling for indexing, validating, creating, and editing GCA definition resources.

## Main areas
- `core/` contains schema, indexing, and validation services.
- `ui/` contains the editable main-screen scene and dock controller.
- `example/` contains sample `.tres` definitions for editor testing.
- `game_data_studio_plugin.gd` is the `EditorPlugin` entry point.

## Rules
- Keep the plugin isolated from runtime `content/core` dependencies in the reverse direction.
- Resources remain the source of truth; do not introduce a parallel database.
- Editor changes must preserve Undo/Redo and standard Godot resource saving.
