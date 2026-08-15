# Context: `content/core/interaction/source/`

## Purpose
Finds, focuses, selects, and submits semantic interaction requests for an interacting object.

## Rules
- Use targeting/handles and target capability contracts, not direct persistent Node references.
- Source code never branches on target type and never calls arbitrary target methods.
- Empty intent requests target default interaction; explicit intent preserves requested semantics.
- Revalidate focused/selected offers before exact offer execution.
