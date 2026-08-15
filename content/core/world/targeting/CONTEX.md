# Context: `content/core/world/targeting/`

## Purpose
Deterministic spatial query service returning object handles and query metadata.

## Rules
- Return handles rather than only raw Nodes.
- Apply stable ordering after physics results.
- Filters use tags, capabilities, exclusions, limits, and explicit visibility policies.
- Abilities, AI, and interactions share this port instead of global SceneTree searches.
