# Context: `content/core/movement/motors/`

## Purpose
Abstract movement motor feature and the `CharacterBody3D` adapter.

## Rules
- Keep the public motor port reusable by future flying, swimming, vehicle, rigid-body, and scripted motors.
- Physics updates occur in the appropriate Godot lifecycle.
- Resolve speed/state through capabilities and explicit exported body references.
