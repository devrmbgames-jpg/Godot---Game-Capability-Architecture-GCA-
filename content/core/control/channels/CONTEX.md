# Context: `content/core/control/channels/`

## Purpose
Central catalog of logical control channel IDs.

## Rules
- Channels represent authority domains, not input action names.
- Add new channels centrally before using them in sources, arbiter, or endpoint code.
- Keep IDs stable for diagnostics and saved/scripted references.
