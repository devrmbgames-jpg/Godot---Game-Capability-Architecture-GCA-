# Context: `content/core/world/ports/`

## Purpose
Central catalog of world-service port IDs injected into object contexts.

## Rules
- Port IDs remain stable and capability-like.
- Add a port only when an explicit cross-object/world service contract is required.
- Ports expose narrow operations rather than unrestricted world-node access.
