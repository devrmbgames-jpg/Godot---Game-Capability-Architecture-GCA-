# Context: `content/core/attributes/modifiers/`

## Purpose
Source-owned runtime attribute modifier records and their stable removal handles.

## Rules
- Preserve modifier identity when magnitude changes.
- Sort diagnostics deterministically by priority, source definition, and creation index.
- Invalidate handles during owner shutdown.
