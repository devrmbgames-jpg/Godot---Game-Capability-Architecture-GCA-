# Context: `content/core/world/streaming/`

## Purpose
Explicit region lifecycle, unload preparation, dormant/offline policy, and resolver invalidation coordination.

## Rules
- Block new incompatible work before unload.
- Capture state before invalidating runtime handles.
- Classify mechanics as freeze, elapsed-time advance, resolve-on-load, or unsupported offline.
- Do not implement a replacement for Godot's scene loading system.
