# Context: `content/core/presentation/`

## Purpose
Gameplay-facing presentation request contracts decoupled from concrete animation, VFX, audio, and camera implementations.

## Rules
- Gameplay requests cues; it does not address AnimationTree paths or effect nodes directly.
- Looping presentation has explicit ownership and cleanup.
- Presentation receivers may be absent in headless tests without changing gameplay results.
