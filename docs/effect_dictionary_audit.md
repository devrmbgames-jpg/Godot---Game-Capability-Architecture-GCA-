# Focused audit: Dictionary data contracts around Effect refactor

## Scope and method

This is a focused static audit of `content/core/**` contracts relevant to the distinction required by the Effect typed-spec refactor: **fixed designer-authored schemas** versus **runtime/dynamic Dictionary data**.

The repository connector available during this change did not expose a reliable code-search index for a mechanical repository-wide `Dictionary` grep, so this document does not claim that every Dictionary occurrence was machine-enumerated. The inspected core definition/runtime modules and their architectural roles were classified instead. Any future broad data-model cleanup should repeat the audit with a local checkout/grep before expanding scope.

## Migrated in this PR

### `GameEffectDefinition.attribute_modifiers`

Previous type:

```text
Array[Dictionary]
```

Classification: fixed, designer-authored nested operation schema with an Attribute ID reference.

Decision: **migrate now** to `Array[GameEffectAttributeModifierSpec]`.

Reason: stable keys, Inspector authoring, validation, typed enum, Identifier Registry integration, and direct runtime consumption all benefit from an explicit Resource contract.

### `GameEffectDefinition.meter_operations`

Previous type:

```text
Array[Dictionary]
```

Classification: fixed, designer-authored nested operation schema with a Meter ID reference.

Decision: **migrate now** to `Array[GameEffectMeterOperationSpec]`.

Reason: same as attribute modifiers; it is definition data, not runtime state.

## Further candidate — do not change in this PR

### `GameAttributes.base_overrides`

Current type:

```text
Dictionary
```

Classification: designer-authored configuration mapping Attribute IDs to base values.

Decision: **future typed-definition candidate**, out of scope for the Effect refactor.

Reason: it has a stable semantic role and ID references, so a typed entry Resource could improve Inspector authoring and future Identifier Registry integration. However, changing it would alter the Attributes authoring contract and requires its own migration and tests.

## Dictionaries intentionally retained

### Runtime indexes and ownership maps

Examples in inspected core runtime code include:

- `GameAttributes._values`;
- `GameAttributes._modifiers_by_handle`;
- `GameAttributes._changed_ids`;
- `GameMeters._values`;
- `GameEffects._active_effects`.

Classification: runtime lookup/index structures.

Decision: **keep Dictionary**. Their key-based lookup semantics are the reason they exist; replacing them with Resource specs would make the runtime model worse.

### Diagnostic snapshots

Examples include:

- `GameAttributeValue.get_debug_snapshot()`;
- `GameAttributes.get_debug_snapshot()`;
- `GameMeters.get_debug_snapshot()`;
- `GameEffects.get_debug_snapshot()` / `GameActiveEffect.to_dictionary()`.

Classification: transient diagnostic/readout data.

Decision: **keep Dictionary**. These are intentionally flexible observation payloads and are not Inspector-authored definitions.

### Event, command, query, and execution payloads

Core gameplay protocols use Dictionaries where payload shape is intentionally contextual/dynamic.

Classification: transient protocol payload.

Decision: **keep Dictionary** unless a particular protocol later establishes a fixed public schema that warrants a dedicated type. This Effect task must not introduce a universal payload Resource.

### Persistence/serialization snapshots

Runtime save snapshots may use Dictionaries as serialization output with their own explicit schema/version boundary.

Classification: serialization DTO/snapshot, not an Inspector-authored nested definition.

Decision: **keep Dictionary in this refactor**. Persistence schema changes require an independent migration contract.

### Editor/Data Studio schema metadata

`GCA Data Studio` uses Dictionaries to describe editor/index metadata and validation reports.

Classification: deliberately dynamic editor metadata/reporting.

Decision: **keep Dictionary**. The validator was updated only where it consumed the Effect operation collections themselves; the editor metadata transport remains dynamic.

## Existing typed-definition precedent

`GameAbilityDefinition` already uses typed nested Resources for fixed designer-authored contracts such as:

```text
Array[GameAbilityRequirement]
Array[GameAbilityCost]
Array[GameAbilityOperation]
```

The Effect refactor follows the same architectural direction instead of introducing a generic Dictionary-backed operation abstraction.

## Rule for future reviews

Promote a Dictionary to a typed Resource when all of the following are true:

1. designers author it as definition data;
2. the key set is stable and documented;
3. fields need validation or ID-domain semantics;
4. Inspector discoverability matters;
5. runtime consumers currently know the serialized key schema.

Keep a Dictionary when its map/dynamic nature is intentional: indexes, snapshots, transient payloads, diagnostics, or editor reports.
