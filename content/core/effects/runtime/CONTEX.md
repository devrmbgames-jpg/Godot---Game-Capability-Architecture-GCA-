# Context: `content/core/effects/runtime/`

## Purpose

`GameActiveEffect` owns per-application state and `GameEffects` orchestrates validation, application, stacking, periodic execution, queries, cleanup, and removal.

Effect operation definitions are typed Resources. Runtime must read their fields directly and must not know or emulate the legacy serialized Dictionary key schema.

## Application flow

```text
GameEffectDefinition
→ GameEffects.apply_effect
→ validate definition + requirements
→ grant tags
→ apply GameEffectAttributeModifierSpec entries
→ apply GameEffectMeterOperationSpec entries
→ retain runtime handles for non-instant effects
→ cleanup/remove owned handles when the effect ends or application fails
```

Attribute modifier batches execute inside `GameAttributes.begin_transaction()` / `end_transaction()`. Modifiers created earlier in a failing batch are removed before the transaction ends, and ownership handles are attached to `GameActiveEffect` only after the complete batch succeeds.

If a later meter operation fails, normal active-effect ownership cleanup removes attribute modifiers and tags already owned by that attempted application. Executed meter deltas are commands, not reversible ownership handles; this refactor does not add a new Meter transaction model.

## Stack semantics

Application preserves the existing scaling contract:

```text
attribute magnitude = spec.magnitude * active_effect.get_stacks()
meter delta         = spec.delta * active_effect.get_stacks()
```

The refactor does not change stacking policy behavior or retroactively rebuild already-owned attribute modifiers when a later application adds a stack.

## Periodic flow

```text
GameEffects.advance_time
→ GameActiveEffect.advance
→ due periodic tick count
→ GameEffectMeterOperationSpec
→ GameMeters.modify_current
```

The same typed meter-operation collection remains the source for initial application and periodic execution. Duration, period, `execute_period_on_apply`, and tick capping remain responsibilities of the existing runtime flow.

## Ownership boundary

- `GameEffectDefinition` and nested specs are immutable authored data.
- `GameActiveEffect` owns remaining time, stacks, source/instigator references, root operation ID, modifier handles, and tag handles.
- `GameAttributes` owns modifier runtime objects and attribute values.
- `GameMeters` owns current meter values.
- `GameTagContainer` owns tag source handles.

## Rules

- Preserve source, instigator, target, and execution-root semantics.
- Avoid modifying active-effect collections during iteration; collect expiry/removal work safely.
- Reject invalid typed specs defensively even though editor/definition validation should catch authoring errors earlier.
- Do not mutate shared definition/spec Resources during gameplay.
- Do not add a runtime legacy Dictionary compatibility path; migration is an authoring/content concern.
