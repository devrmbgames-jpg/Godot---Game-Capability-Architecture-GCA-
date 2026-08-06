# Context: `content/core/interaction/source/`

## Purpose
Finds, filters, selects, and executes offers for an interacting object.

## Rules
- Use targeting/handles and target query contracts, not direct persistent Node references.
- Revalidate focus and selected offers before execution.
- Delegate mechanics through ability/command APIs and return structured reasons.
