# Context: `content/core/world/objects/`

## Purpose
Canonical stable-ID registration and streaming-aware object handle resolution.

## Rules
- One canonical handle represents each known stable object ID.
- Unload invalidates runtime references while preserving known identity.
- Duplicate live registrations return deterministic errors.
- Never retain strong cross-region Node references.
