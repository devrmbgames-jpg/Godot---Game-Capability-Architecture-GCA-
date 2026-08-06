# Context: `content/core/abilities/requirements/`

## Purpose
Pure activation requirement strategies that return structured availability reasons.

## Rules
- Requirements never mutate state, spend costs, or start executions.
- Report stable reason codes and temporary/permanent classification where available.
- Depend on queries, tags, capabilities, and normalized target data.
