# Context: `content/core/world/spawn/`

## Purpose
World-owned spawn/despawn requests, stable-ID policy, parenting, registration, and handle results.

## Rules
- Gameplay abilities request spawning through this service instead of calling `PackedScene.instantiate()` directly.
- Distinguish gameplay death, permanent destruction, streaming unload, pooling, and expiration.
- Register/invalidate handles consistently with the object resolver.
