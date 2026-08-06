# Context: `content/core/world/context/`

## Purpose
`GameWorldContext` composition root that exposes an allow-listed map of scene-local service ports to object kernels.

## Rules
- Features should receive only the ports they need.
- Do not store object-local gameplay state in world context.
- Service registration and lookup use stable port IDs.
