# Stage 5 — World Services, Persistence and Integrations API

## World composition

Create `GameWorldContext` in the world scene and assign `GameObjectResolver`, `GameSpawnService`, `GameTargetingService`, `GameTimeService`, `GamePersistenceCoordinator`, and `GameRegionStreamingService`. It is not an Autoload. Call `bind_kernel()` before kernel initialization.

## Handles and streaming

`GameObjectHandle` has explicit states: resolved, unresolved-known, loading-requested, invalid-permanent, and ephemeral-expired. `GameObjectResolver` owns the canonical handle for each stable ID. Region unload calls `mark_unresolved`; permanent destruction calls `invalidate_permanently`. Cross-region strong Node references are forbidden.

## Spawn and targeting

Abilities use the `spawn.request` world port rather than `PackedScene.instantiate()`. `GameTargetingService.query_sphere()` returns stable handles and metadata, sorted by distance then stable ID.

## Time

Schedulers subscribe to `GameTimeService.simulation_advanced`. Tests disable `auto_advance` and call `advance(delta)` directly.

## Persistence

Register each object and explicit `GamePersistenceParticipant`. Capture saves stable IDs, scene/region IDs, transform and versioned component snapshots, not SceneTree. Restore phases are validation/migration, local restore, reference resolution and gameplay activation. Effects and grants require a game-owned definition registry to resolve saved IDs; unknown definitions must produce a report.

## GOAP

`GameGOAPAdapter` projects tags/meters into `GoapWorldState.set_state` and sends intents through `GameControlSource`. It never mutates physics, meters or effects directly. Reviewed upstream contract: `GoapAgent.init/process`, `GoapWorldState.set_state/get_state`, action lifecycle `enter/perform/exit`.

## Dialogue Manager

Expose only `GameDialogueAdapter` to dialogue conditions/mutations. Participants are addressed by stable ID. Pin a tested plugin revision; upstream main targets Godot 4.6+ and is the v4 prerelease line.

## Inventory System

Plugin events enter through `GameInventoryAdapter`. Equip creates item-owned effect/grant handles; unequip removes only those handles. Stable item instance IDs make application idempotent and allow reconciliation after load. Pin the chosen plugin branch/release.

## Manual cycle

1. Copy text files; do not copy project/binary artifacts.
2. Build the world service hierarchy.
3. Bind kernels before initialization.
4. Register persistent participants before capture.
5. Route streaming lifecycle into resolver states.
6. Connect addon signals only inside adapters.
7. Run Stage 1–5 contract tests in Godot 4.6.
8. Profile targeting, save/load and projections before moving code to C#.

## Validation limits

The repository intentionally contains no `project.godot`, scenes, `.tres`, `.uid`, or binary assets. The implementation includes isolated contract tests, but import/parser/runtime validation must be performed after copying the scripts into the target Godot 4.6 project.
