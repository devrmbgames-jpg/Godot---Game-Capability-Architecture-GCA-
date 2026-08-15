# Context: `content/core/interaction/operations/`

## Purpose
Ability operations that bridge a generic source-owned interaction ability into the interaction target contract.

## Rules
- `GameInteractionAbilityOperation` resolves `GameInteractionSource` by capability.
- Explicit ability target wins; otherwise current interaction focus is used.
- Optional semantic intent is read from normalized activation payload.
- Operations never inspect target classes or call target gameplay methods directly.
