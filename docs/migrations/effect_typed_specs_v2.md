# Effect typed specs migration — schema v2

## Scope

`GameEffectDefinition` schema v2 replaces the two implicit designer-authored operation collections:

```text
attribute_modifiers: Array[Dictionary]
meter_operations: Array[Dictionary]
```

with:

```text
attribute_modifiers: Array[GameEffectAttributeModifierSpec]
meter_operations: Array[GameEffectMeterOperationSpec]
```

The old serialized form had no explicit `schema_version`. For migration purposes this document names that legacy Dictionary representation **schema v1**. Typed effect definitions explicitly serialize `schema_version = 2`.

This is a one-pass content migration. Gameplay runtime does not contain a legacy Dictionary loader.

## Legacy attribute modifier contract

The runtime historically read these keys and fallbacks:

| Legacy key | Typed field | Legacy fallback |
| --- | --- | --- |
| `attribute_id` | `GameEffectAttributeModifierSpec.attribute_id` | empty `StringName` |
| `operation` | `GameEffectAttributeModifierSpec.operation` | `GameAttributeModifier.Operation.ADD` |
| `magnitude` | `GameEffectAttributeModifierSpec.magnitude` | `0.0` |
| `priority` | `GameEffectAttributeModifierSpec.priority` | `0` |

Migration materializes those exact defaults. An empty target ID therefore becomes an explicitly invalid typed spec rather than silently targeting anything.

Numeric `magnitude` accepts a legacy `int` or `float` and materializes a `float`. `operation` must be an integer value of the existing `GameAttributeModifier.Operation` contract. `priority` must be an `int`.

## Legacy meter operation contract

| Legacy key | Typed field | Legacy fallback |
| --- | --- | --- |
| `meter_id` | `GameEffectMeterOperationSpec.meter_id` | empty `StringName` |
| `delta` | `GameEffectMeterOperationSpec.delta` | `0.0` |

Numeric `delta` accepts a legacy `int` or `float` and materializes a `float`. An empty meter target is invalid after migration.

## Unknown keys

Unknown legacy keys are a hard migration error. They are never silently discarded.

`GameEffectLegacyMigrator` returns a report with `ok == false` and indexed error messages. A failed report must not be written back as migrated content. The developer must decide whether the unknown field represents obsolete data or requires an explicit extension of the typed spec contract.

The same rule applies to non-string Dictionary keys and incompatible value types.

## Migration helper

Tooling helper:

```text
res://tools/migrations/game_effect_legacy_migrator.gd
```

Public conversion entry points:

```text
GameEffectLegacyMigrator.migrate_attribute_modifier(...)
GameEffectLegacyMigrator.migrate_meter_operation(...)
GameEffectLegacyMigrator.migrate_operation_arrays(...)
```

The helper does not mutate the supplied legacy Dictionaries. It creates new typed Resources and validates them before reporting success.

## Project content migrated in this change

The repository contained one authored effect definition under `content/gameplay/effects/definitions/`: `eff_def_burning.tres`.

Its legacy meter operation:

```text
meter_id = base.meter.health
delta = -5.0
```

is represented by an embedded `GameEffectMeterOperationSpec` in schema v2. Duration, period, stacking, granted tag, and delta values are unchanged.

## Runtime semantics preserved

Attribute modifier scaling remains:

```text
applied_magnitude = spec.magnitude * active_effect.stacks
```

Meter operation scaling remains:

```text
applied_delta = spec.delta * active_effect.stacks
```

`GameEffects` still executes the meter operation collection on initial effect application and on periodic ticks according to the existing active-effect scheduling flow.

Attribute modifiers are applied inside an Attributes transaction. If a later modifier cannot be configured, modifiers already created for that batch are removed before the transaction ends. They are attached to `GameActiveEffect` ownership only after the whole modifier batch succeeds.

If a later meter operation fails, normal effect ownership cleanup removes already-owned attribute modifiers and granted tags. Meter operations themselves remain sequential commands; this refactor does not invent a new rollback transaction for already-executed meter deltas.

## Identifier Registry boundary

The typed ID fields are intentionally plain runtime `StringName` fields:

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

They are ready for the separate GCA Identifier Registry/Inspector work. The effect runtime and spec classes do not depend on editor plugin classes.

## Verification

The dedicated test scene is:

```text
res://content/core/testing/scenes/test_effect_typed_specs_runner.tscn
```

It covers spec validation, nested definition validation, deterministic legacy defaults, unknown-key rejection, runtime application/cleanup, attribute batch atomicity, meter-failure cleanup, instant cleanup, and periodic stack scaling.
