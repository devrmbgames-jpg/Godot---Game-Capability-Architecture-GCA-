# Context: `content/core/presentation/cues/`

## Purpose
Portable cue request data for start, stop, update, and one-shot presentation actions.

## Rules
- Carry cue ID, owner/source/target handles, execution identity, context tags, magnitude, and transform/socket hints.
- Keep requests independent from concrete scene-node paths.
- Preserve ownership for automatic cleanup.
