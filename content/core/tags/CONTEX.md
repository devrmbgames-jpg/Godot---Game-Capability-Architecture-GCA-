# Context: `content/core/tags/`

## Purpose
Hierarchical gameplay tag IDs, optional catalog validation, source-owned tag handles, and the tag feature.

## Rules
- Tags represent boolean facts/categories, not numeric values or complex state.
- Multiple sources may grant the same tag; remove only the matching handle.
- Parent-tag checks are explicit and use dot hierarchy.
- Keep known IDs centralized and stable.
