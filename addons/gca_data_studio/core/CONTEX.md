# Context: `addons/gca_data_studio/core/`

## Purpose
Editor-only services that describe supported definition schemas, scan project resources, and validate indexed data.

## Classes
- `GameDataSchemaRegistry` defines supported resource metadata and columns.
- `GameDataIndex` builds deterministic resource records.
- `GameDataValidator` reports stable-ID, configuration, and reference issues.

## Rules
- Keep services independent from UI node structure.
- Validation must be deterministic and must not mutate gameplay definitions.
- New supported definition types require schema, index, validator, and UI compatibility review.
