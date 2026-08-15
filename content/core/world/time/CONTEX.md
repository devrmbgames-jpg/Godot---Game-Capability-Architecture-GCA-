# Context: `content/core/world/time/`

## Purpose
Shared gameplay simulation time, pause/time-scale policy, and deterministic manual advancement for tests.

## Rules
- Distinguish gameplay time from real/UI time.
- Effects and cooldowns consume this contract instead of frame count assumptions.
- Save remaining durations or stable timestamps according to explicit policy.
