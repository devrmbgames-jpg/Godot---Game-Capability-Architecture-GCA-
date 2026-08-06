# Context: `content/core/attributes/definitions/`

## Purpose
Immutable `GameAttributeDefinition` resources: IDs, defaults, clamp policy, metadata, and save hints.

## Rules
- Do not store per-owner runtime values here.
- Stable IDs and validation rules are public data contracts.
- Runtime code may read but must not mutate shared definitions.
