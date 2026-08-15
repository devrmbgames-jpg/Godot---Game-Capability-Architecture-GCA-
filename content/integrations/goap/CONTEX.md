# Context: `content/integrations/goap/`

## Purpose
Projects GCA state into GOAP facts and translates GOAP actions into standard control intents and gameplay requests.

## Rules
- GOAP is a decision source, not gameplay source of truth.
- Actions do not move bodies or mutate meters/effects directly.
- Map core failure reasons to GOAP outcomes and replanning hints.
- Keep GOAP fact keys and plugin APIs outside `content/core`.
