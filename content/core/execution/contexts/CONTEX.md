# Context: `content/core/execution/contexts/`

## Purpose
Causal execution-chain data: operation IDs, root/parent linkage, handles, targets, tags, deterministic seed, and captured values.

## Rules
- Child contexts preserve root ID and increment depth.
- Seed derivation must remain deterministic.
- Source and instigator change only through explicit policy.
- Snapshots use stable IDs rather than strong Node references.
