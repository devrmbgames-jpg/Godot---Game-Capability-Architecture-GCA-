# Context: `content/core/capabilities/`

## Purpose
Stable capability identifiers, cardinality/dependency contracts, and the local object capability registry.

## Rules
- Capability IDs are centralized `StringName` constants.
- Registries are object-local, not global service locators.
- Exclusive/multi cardinality must be validated before activation.
- Features cache resolved dependencies for hot-path access.
