# Context: `content/core/execution/results/`

## Purpose
Structured command outcomes for gameplay, AI, UI, diagnostics, and tests.

## Rules
- Prefer stable status and reason codes over booleans or parsed messages.
- Attach source operation IDs for causal tracing.
- Distinguish success-with-change, success-without-change, gameplay rejection, and configuration failure.
