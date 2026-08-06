# Context: `content/core/control/endpoint/`

## Purpose
Validates channel ownership and routes normalized intents to movement, abilities, and interaction capabilities.

## Rules
- Reject intents from non-owners or blocked channels with stable reasons.
- Missing executors are valid composition outcomes and return missing-capability results.
- Clear continuous intents when ownership is lost.
