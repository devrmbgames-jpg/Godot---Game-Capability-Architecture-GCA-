# Context: `content/core/effects/definitions/`

## Purpose

Immutable `GameEffectDefinition` configuration for duration, period, stacking, tags, typed attribute modifiers, and typed meter operations.

The fixed nested operation schemas are Resources rather than Dictionaries:

```text
GameEffectDefinition
├── Array[GameEffectAttributeModifierSpec]
└── Array[GameEffectMeterOperationSpec]
```

`GameEffectAttributeModifierSpec` describes one Attribute modifier using the existing `GameAttributeModifier.Operation` enum contract. `GameEffectMeterOperationSpec` describes one Meter current-value delta. Neither class stores active handles, owner Nodes, remaining duration, stacks, or other per-target state.

## Serialized schema

Effect schema v2 replaces the legacy Dictionary collections. `GameEffectDefinition.schema_version` must equal `CURRENT_SCHEMA_VERSION` and nested specs participate in `get_validation_errors()` / `is_valid()`.

The migration contract and legacy defaults are documented in:

```text
res://docs/migrations/effect_typed_specs_v2.md
```

Runtime does not load legacy Dictionary operation specs.

## Stack semantics

Attribute modifier magnitude is interpreted as:

```text
applied_magnitude = spec.magnitude * active_effect.stacks
```

Meter operation delta is interpreted as:

```text
applied_delta = spec.delta * active_effect.stacks
```

Stack scaling policy is runtime interpretation. Specs remain immutable authored data.

## Identifier references

The typed target fields are future Identifier Registry references:

```text
GameEffectAttributeModifierSpec.attribute_id
  domain: attribute
  role: reference
  scope: project_global

GameEffectMeterOperationSpec.meter_id
  domain: meter
  role: reference
  scope: project_global
```

The Resource classes must not depend on the editor plugin or Identifier Inspector runtime classes.

## Inspector authoring

Designers edit nested Resources directly inside an Effect Definition:

```text
Attribute Modifiers
  [0]
    Attribute Id
    Operation
    Magnitude
    Priority

Meter Operations
  [0]
    Meter Id
    Delta
```

The standard typed Resource Inspector is the baseline. A separate Identifier Inspector may later replace manual `StringName` entry with domain-aware pickers.

## Validation

- Effect ID must be non-empty.
- Duration/period and stack constraints remain validated.
- Every nested spec must be non-null and valid.
- Attribute target, operation, and magnitude are validated by `GameEffectAttributeModifierSpec`.
- Meter target and delta are validated by `GameEffectMeterOperationSpec`.
- Definition errors include collection, index, target ID where available, and nested reason.
- Data Studio additionally checks whether referenced Attribute/Meter IDs exist in its indexed project definitions.

## Rules

- Treat definition Resources as immutable during gameplay runtime.
- Do not store remaining time, handles, stacks, owner state, or execution state in definitions/specs.
- Do not reintroduce arbitrary Dictionary payloads for fixed Effect operation schemas.
- Keep runtime ownership in `GameActiveEffect`, `GameAttributes`, `GameMeters`, and tag runtime systems.
