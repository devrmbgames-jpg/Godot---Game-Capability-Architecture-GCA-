# Context: `content/core/abilities/costs/`

## Purpose
Ability cost contracts and concrete meter-backed cost preparation.

## Key classes
- `GameAbilityCost` defines check, prepare, commit, rollback, and refund hooks.
- `GameAbilityMeterCost` implements meter debit through the owner capability.

## Rules
- Multi-cost activation must prepare all required mutations before commit.
- Failure must not leave partial resource changes.
- Costs return structured results and never hide mutations in query methods.
