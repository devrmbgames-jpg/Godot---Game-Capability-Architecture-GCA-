# Context: `content/core/testing/`

## Purpose
Lightweight contract tests for core stages that can run without full gameplay content or presentation.

## Rules
- Tests use public contracts and assert structured outcomes.
- Keep fixtures deterministic and independent from external addons unless placed in integration-specific suites.
- Runtime execution must be performed in the target Godot 4.6 project because this repository has no `project.godot`.
