# Context: `addons/gca_data_studio/ui/`

## Purpose
Editable Godot UI scene and controller for the GCA Data Studio main screen.

## Key files
- `ui_gca_data_studio.tscn` owns visual layout and exported node bindings.
- `game_data_studio_dock.gd` owns editor workflow and table behavior.

## Rules
- Keep layout authorable in the scene instead of rebuilding it in code.
- Preserve exported reference types and required control assignments.
- Gameplay state must not be stored in this editor UI.
