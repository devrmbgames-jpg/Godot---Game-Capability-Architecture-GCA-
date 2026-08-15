# Context: `content/core/interaction/requests/`

## Purpose
Normalized semantic interaction requests shared by abilities, AI, scripted control, sources, and targets.

## Rules
- Empty intent/offer means contextual default interaction.
- `intent_id` expresses desired semantics such as `open`, never a target class or method name.
- `offer_id` may select one exact currently advertised target reaction.
- Requests carry object handles and execution context, not persistent gameplay Node references.
