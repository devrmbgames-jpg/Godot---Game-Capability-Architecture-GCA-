# Context: `content/core/movement/`

## Purpose
Movement request contracts and motor ports that isolate control decisions from physics execution.

## Rules
- Motors are the only low-level owners of body velocity/transform changes.
- Control sources and abilities submit requests rather than mutating physics bodies.
- Motor implementations do not read `Input` or choose AI goals.
