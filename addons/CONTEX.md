# Context: `addons/`

## Purpose
Contains editor plugins and third-party addons used by the project.

## Navigation
- `gca_data_studio/` is GCA-owned editor tooling.
- Other addon folders are vendor-owned and must not be edited as part of core GCA work unless an explicit plugin upgrade is requested.

## Rules
- Core gameplay code must not depend directly on vendor addon classes.
- Addon integrations belong in `content/integrations/`.
- Read the nearest child `CONTEX.md` before editing owned addon code.
