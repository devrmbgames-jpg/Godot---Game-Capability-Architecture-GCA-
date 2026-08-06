# Context: `content/core/persistence/`

## Purpose
Versioned component snapshot participation and phased world restore coordination.

## Rules
- Save stable object/component IDs and schema versions, not the full SceneTree.
- Migrate snapshots stepwise and report object/component/version failures structurally.
- Restore local state before enabling gameplay that depends on unresolved cross-object references.
- Unknown components follow explicit compatibility policy.
