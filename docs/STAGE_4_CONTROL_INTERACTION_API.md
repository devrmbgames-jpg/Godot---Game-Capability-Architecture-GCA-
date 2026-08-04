# Stage 4 — Control, Movement, Interaction and Presentation API

Stage 4 adds one control pipeline for player input, mock AI and scripted/cutscene control. It builds on the existing Foundation and Ability APIs and does not add `project.godot`, binary resources, plugin integrations or world services.

## Object composition

For a controllable `CharacterBody3D`, add these direct children to `GameObjectKernel`:

```text
GameControlArbiter
GameControlEndpoint
GameCharacterMotor
GameAbilities                 # optional
GameInteractionSource         # optional
GamePresentationCueReceiver   # optional
```

Control sources are external decision producers. Attach a source explicitly:

```gdscript
var context := kernel.get_object_context()
var endpoint := context.get_capability(GameCapabilityIds.CONTROL_ENDPOINT) as GameControlEndpoint
var arbiter := context.get_capability(GameCapabilityIds.CONTROL_ARBITER) as GameControlArbiter

player_source.set_execution_context_factory(func(cause: StringName, label: String) -> GameExecutionContext:
	return kernel.create_root_execution_context(cause, label)
)
player_source.attach(endpoint, arbiter)
player_source.request_control()
```

## Control ownership

Channels are independent: `movement`, `look`, `abilities`, `interaction`, `camera`, `targeting`, `ui_navigation`.

A higher-priority source can preempt a lower-priority owner. A scripted source can use temporary ownership and release it later; the arbiter restores the previous registered source automatically.

```gdscript
scripted_source.acquire_temporary([
	GameControlChannels.MOVEMENT,
	GameControlChannels.LOOK,
])

scripted_source.move_to(target_position, 0.25, context)

scripted_source.release_channels([
	GameControlChannels.MOVEMENT,
	GameControlChannels.LOOK,
])
```

## Intents

All sources create `GameControlIntent`. Sources never move physics bodies, activate internal executions or call interactable methods directly.

The endpoint validates ownership and blocking tags, then routes:

- movement/look → `GameMovementMotor`;
- abilities → Stage 3 `GameAbilityActivationRequest`;
- interaction → `GameInteractionSource`.

Supported blocking tags include `control.block.all`, `control.block.<channel>` and `state.dead`.

## Movement

`GameCharacterMotor` is the first Godot-native motor adapter. It requires a `CharacterBody3D` object root and optionally reads `movement_speed` from `GameAttributes`. It owns `velocity`, gravity, facing and `move_and_slide()`.

```gdscript
mock_ai.move(Vector3.FORWARD, 1.0, context)
mock_ai.stop(context)
```

Temporary movement restrictions use source-owned constraint handles:

```gdscript
var handle_id := motor.add_constraint(&"movement.disabled", {"source": "stun"})
motor.remove_constraint(handle_id)
```

## Interaction

`GameInteractionTarget` provides runtime `GameInteractionOffer` values. `GameInteractionSource` stores focus by object handle, re-queries offers before execution and optionally creates a reservation.

```gdscript
mock_ai.focus_interaction(door_handle, context)
interaction_source.select_offer(&"open")
interaction_source.execute_selected(context)
```

Ability-backed offers activate the ability on the source and pass the target handle plus offer metadata. Reservation cleanup occurs after execution, cancellation and shutdown.

Current first-version boundary: command-backed offers expose a stable contract but require a command-definition registry in a later increment.

## Presentation

Gameplay emits `GamePresentationCueRequest` through `GamePresentationCueReceiver`. The receiver does not know AnimationTree paths, audio buses or particle nodes.

Looping cues require an ownership key and can be stopped by key or execution ID.

## Source responsibilities

- `GamePlayerInputSource` is the only Stage 4 class that reads Godot `Input`.
- `GameMockAIControlSource` exposes deterministic helper methods for tests and future GOAP adaptation.
- `GameScriptedControlSource` supports temporary channel takeover and restoration.

## Integration loop

A typical owner-level physics loop remains responsible for Stage 2/3 scheduler advancement:

```gdscript
func _physics_process(delta: float) -> void:
	abilities.advance_time(delta)
	effects.advance_time(delta, kernel.create_root_execution_context(&"simulation.effects_tick"))
	kernel.process_execution_queue()
```

`GameCharacterMotor` runs its own physics callback because it owns Godot physics movement. Grants, effects, reservations and control intents do not create per-instance processing nodes.

## Known limits

- World focus/spatial queries are deferred to Stage 5; the first version accepts explicit target handles.
- Hold and paired interaction data contracts are reserved, but full asynchronous execution waits are not implemented in Stage 3.
- Camera and animation ports are represented by presentation cues; concrete rigs/adapters remain game content.
- No scenes, `.tres`, `.uid`, `project.godot` or binary resources are included.
