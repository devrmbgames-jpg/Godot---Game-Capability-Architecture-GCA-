# Context: `content/core/world/`

## Purpose
Scene-local world composition, stable object resolution, spawn/despawn, targeting, simulation time, and region streaming services.

## Rules
- World services are scene-owned ports, not universal gameplay Autoloads.
- Cross-region references use stable handles and weak runtime resolution.
- Services send commands through kernels rather than calling object features directly.
- Deterministic ordering and structured metadata are required for queries.
