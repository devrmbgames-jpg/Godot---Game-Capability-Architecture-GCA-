# Context: `content/core/control/`

## Purpose
Unified control pipeline for player, AI, scripted, and future control sources.

## Flow
`GameControlSource → GameControlArbiter → GameControlEndpoint → executor capabilities`.

## Rules
- Sources produce normalized intents and never mutate gameplay systems directly.
- Channel ownership is explicit and independently arbitrated.
- Endpoint routing returns structured results for missing or blocked capabilities.
