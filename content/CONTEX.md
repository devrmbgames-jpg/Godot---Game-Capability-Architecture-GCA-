# Context: `content/`

## Purpose
Contains project-owned runtime framework, integration adapters, and game-specific content.

## Navigation
- `core/` contains universal GCA contracts and runtime systems.
- `integrations/` isolates external addon APIs.
- Game-specific definitions and scenes belong in thematic gameplay folders when added.

## Rules
- Dependencies point from gameplay to integrations to core.
- Core must not import concrete gameplay content or third-party plugin classes.
- Follow the nearest child `CONTEX.md` before editing a subsystem.
