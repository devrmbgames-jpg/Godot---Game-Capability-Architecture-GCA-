# Context: `content/core/capabilities/registry/`

## Purpose
Deterministic object-local provider registration and dependency resolution.

## Rules
- Reject conflicting exclusive providers with structured configuration errors.
- Return stable copies of multi-provider collections.
- Do not search the SceneTree from registry queries.
- Registry mutations are coordinated by `GameObjectKernel`.
