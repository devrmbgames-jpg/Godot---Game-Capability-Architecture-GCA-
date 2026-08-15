# Context: `content/core/execution/`

## Purpose
Addressed commands, side-effect-free queries, completed-fact events, structured results, causal contexts, and queued operations.

## Rules
- Commands have one explicit target and return `GameCommandResult`.
- Queries do not mutate state.
- Events describe facts that already occurred.
- Child operations are queued to avoid recursive chains and collection mutation.
