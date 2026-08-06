# GCA Repository Context

This repository contains Game Capability Architecture (GCA), a modular gameplay framework for Godot Engine 4.6.

## Start here

- Read `README.md` for the framework overview and runtime workflow.
- Read `docs/` for stage-specific public API guides.
- Read the nearest `CONTEX.md` before editing a directory.
- Treat `content/core/` as stable framework infrastructure.
- Treat `content/gameplay/` as game-specific definitions and examples.
- Treat `content/integrations/` as adapters around third-party addons.
- Do not edit third-party addon sources unless the task explicitly targets that addon.

## Architectural invariants

- Compose gameplay objects with one local `GameObjectKernel` and direct child `GameFeature` nodes.
- Depend on capabilities and explicit ports, not concrete owner classes.
- Parent nodes may call children; children report upward through signals or local events.
- Do not call sibling features through `get_parent()` and do not send commands downward through signals.
- Keep shared resource definitions immutable at runtime.
- Use handles for ownership and removal of modifiers, effects, tags, grants, constraints, and reservations.
- Use structured command results and side-effect-free queries.
- Queue child operations to preserve deterministic order and prevent recursion.

## Code conventions

- Gameplay classes begin with `Game`.
- GDScript is strictly typed; unused arguments begin with `_`.
- Public and virtual methods require Godot `##` documentation comments.
- Class documentation appears immediately before `class_name`.
- Keep examples in comments minimal; put multi-step examples in `docs/`.
- Follow the established script section order.

## Change discipline

- One class documentation change per commit.
- Documentation/navigation files may use their own focused commits.
- Avoid behavior changes while adding API documentation.
- Preserve public IDs, serialized field names, capability IDs, and resource schemas.
