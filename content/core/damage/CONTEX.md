# Context: `content/core/damage/`

## Purpose
Generic damage request and receiver pipeline targeting the `damage.receiver` capability.

## Rules
- Damage is not tied to character classes.
- Negative damage is not healing.
- Mitigation remains replaceable and damage types use tags/data.
- Apply meter changes and publish results with the original execution context.
