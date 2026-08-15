# Context: `content/core/abilities/loadout/`

## Purpose
Logical ability slots that resolve control intents to source-owned ability grant handles.

## Model
- `GameAbilitySlotDefinition` configures initial slot-to-ability assignments.
- `GameAbilitySlotBinding` is one runtime source-owned slot binding.
- `GameAbilityLoadout` resolves the highest-priority valid binding for each slot.

## Rules
- Slots reference grant handles at runtime, never own ability execution state.
- Multiple sources may bind the same slot; higher priority wins deterministically.
- Removing or invalidating an overriding grant reveals the next valid binding.
- Input actions do not belong in ability definitions or the loadout.
