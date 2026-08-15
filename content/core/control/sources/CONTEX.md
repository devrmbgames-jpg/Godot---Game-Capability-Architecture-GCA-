# Context: `content/core/control/sources/`

## Purpose
Base, player-input, scripted, and mock-AI producers of normalized control intents.

## Rules
- Sources do not move bodies, activate internal executions, modify meters, or call interaction targets directly.
- Ownership is requested through the arbiter.
- Player input is translated into intents; AI and scripts use the same endpoint contract.
- Player ability input maps `InputAction -> slot_id`; concrete ability/grant resolution belongs to the controlled object.
