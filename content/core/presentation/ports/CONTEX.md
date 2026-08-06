# Context: `content/core/presentation/ports/`

## Purpose
Receiver capability for consuming and owning gameplay presentation cue requests.

## Rules
- Receivers translate stable cue IDs into project-specific visuals/audio/animation.
- Stop only cues owned by the supplied source/execution handle.
- Do not feed presentation-only state back into core gameplay truth.
