# Stage 4 — Control, Movement, Interaction and Presentation API

Stage 4 adds one control pipeline for player input, AI and scripted/cutscene control. It builds on Foundation and Ability APIs and does not add `project.godot`, binary resources, plugin integrations or world services.

## Object composition

For a controllable `CharacterBody3D`, typical direct children of `GameObjectKernel` are:

```text
GameControlArbiter
GameControlEndpoint
GameCharacterMotor
GameAbilities                 # optional
GameAbilityLoadout            # optional, logical action slots
GameInteractionSource         # optional, focus + semantic requests
GamePresentationCueReceiver   # optional
```

An interactable object uses its own ability owner:

```text
GameAbilities
GameInteractionTarget
```

`GameInteractionTarget` requires local `GameAbilities` because interaction reactions execute abilities owned by the target itself.

A character/NPC may contain both `GameInteractionSource` and `GameInteractionTarget`. The source owns `interaction.query`; the target owns `interaction.target`/`interaction.reservable`, so the two roles do not collide as exclusive capabilities.

## Control ownership

Channels remain independent: `movement`, `look`, `abilities`, `interaction`, `camera`, `targeting`, `ui_navigation`.

Higher-priority sources may temporarily preempt lower-priority owners. Releasing temporary ownership restores the previous registered owner.

## Ability intents and loadout

All sources create normalized `GameControlIntent`. Sources never move physics bodies, start internal executions or call interactable methods directly.

Ability intents support:

```text
grant_handle_id   # exact runtime grant
slot_id           # logical slot through GameAbilityLoadout
ability_id        # GameAbilities selection policy
```

Player input should normally send `slot_id`. AI/scripted systems may use slots, ability IDs or exact grants depending on their decision contract.

`GamePlayerInputSource` stores arbitrary `GameAbilityInputBinding` resources:

```text
attack      → slot.primary
secondary   → slot.secondary
dodge       → slot.mobility
interact    → slot.interaction
```

The input layer contains only `input_action` and `slot_id`; ability definitions never know physical buttons.

Runtime path:

```text
Input action
→ GamePlayerInputSource
→ ability intent { slot_id }
→ GameControlEndpoint
→ GameAbilityLoadout.resolve_slot()
→ grant_handle_id
→ GameAbilities.activate()
```

## Interaction model

Interaction is ability-driven on both sides.

The interacting object owns one generic ability, for example:

```text
ability.interact
└── GameInteractionAbilityOperation
```

The operation means only "interact with something". It does not know `Door`, `Chest`, `NPC`, `Lever` or arbitrary method names.

The target exposes `GameInteractionReaction` resources. Each reaction maps semantic intent to a target-local ability:

```text
Door reactions
├── intent.open  → ability.door.open
└── intent.close → ability.door.close
```

The target owns those abilities. For a door-open reaction the activation identity is conceptually:

```text
owner      = Door
requester  = Character/NPC/AI actor
target     = requester (when useful to the target ability)
```

Thus the source asks; the target decides and performs.

### Default interaction

An empty interaction intent means:

> perform the target's default currently executable reaction.

`GameInteractionTarget` considers only reactions with `default_candidate = true`, sorts them by priority, and uses `GameAbilities.query_activation()` to find the first currently available reaction.

This makes contextual behavior data-driven. A door may have:

```text
ability.door.open
    blocked by state.open

ability.door.close
    requires state.open
```

Both reactions can be configured once. When closed, only `open` is advertised/executable; when open, only `close` is advertised/executable. Door glue does not rebuild offers and no controller checks door state.

### Explicit semantic intent

`GameInteractionRequest.intent_id` may specify a desired semantic result:

```text
open
close
talk
loot
enter
exit
activate
deactivate
```

Explicit intent is strict. `intent.open` considers only reactions whose `intent_id == open`.

Therefore:

```text
request(open) against CLOSED door  → ability.door.open
request(open) against OPEN door    → rejected/unchanged according to open ability requirements
request(open) against OPENING door → rejected/busy according to open ability requirements
```

It never silently becomes `close`.

This is useful for GOAP, scripted sequences and other systems that know the state they are trying to achieve.

### Generic interact ability

`GameInteractionAbilityOperation` uses the first explicit ability target when one is supplied. Otherwise it uses the current `GameInteractionSource` focus.

Normal player interaction therefore needs no dedicated interaction button field in `GamePlayerInputSource`:

```text
Input "interact"
→ slot.interaction
→ ability.interact
→ GameInteractionAbilityOperation
→ focused GameInteractionTarget
→ default reaction
→ target-local ability
```

For an advanced request, activate the same generic ability with:

```gdscript
request.set_activation_payload({
	GameInteractionRequest.ACTIVATION_INTENT_KEY: &"open",
})
```

and optionally set an explicit target handle in the normal ability target list.

Mock AI can use the same path without a door-specific method:

```gdscript
ai_control_source.use_ability(
	&"ability.interact",
	[door_handle],
	execution_context,
	{GameInteractionRequest.ACTIVATION_INTENT_KEY: &"open"}
)
```

The AI knows the semantic goal `open`, not the target's local `ability.door.open` implementation.

### Offers

`GameInteractionOffer` is a runtime semantic description for UI/AI selection. It contains:

```text
offer_id
intent_id
verb_id
target_handle
priority
reservation_required
hold_duration
metadata
```

It intentionally has **no `ability_id` and no `command_id`**. Execution details belong only to `GameInteractionReaction`/`GameInteractionTarget`, so consumers cannot accidentally couple UI/control code back to target implementation.

`GameInteractionTarget.query_offers()` derives offers from reactions whose local abilities currently pass `query_activation()`. UI and AI can therefore inspect available actions without learning target-local ability IDs.

### Exact offer selection

`GameInteractionSource` may focus a target, query offers, select one `offer_id`, and execute that exact offer. Exact offer selection is useful when several reactions share a semantic intent but differ in presentation/priority.

Resolution precedence at the target is:

```text
exact offer_id
→ semantic intent_id
→ default available reaction
```

### Direct control interaction intents

The `interaction` control channel remains available for AI/scripted adapters that need focus, offer selection or semantic interaction commands.

`GamePlayerInputSource` no longer emits `interaction.execute` from a hardcoded `interaction_action`; the normal player button should be an ability-slot binding to the generic interaction ability.

## Movement

`GameCharacterMotor` is the first Godot-native motor adapter. It requires a `CharacterBody3D` object root and may read `movement_speed` from `GameAttributes`. It owns velocity, gravity, facing and `move_and_slide()`.

Temporary movement restrictions use source-owned constraint handles.

## Presentation

Gameplay emits `GamePresentationCueRequest` through `GamePresentationCueReceiver`. The receiver does not know AnimationTree paths, audio buses or particle nodes.

## Runtime scheduler ownership

The owner/subscene may keep scheduler advancement local:

```gdscript
func _physics_process(delta: float) -> void:
	abilities.advance_time(delta)
	effects.advance_time(
		delta,
		kernel.create_root_execution_context(&"simulation.effects_tick")
	)
	kernel.process_execution_queue()
```

This is intentional. GCA does not require one global scheduler. Local ticking keeps entity/subscene profiling and debugging explicit and leaves room for project-specific execution/threading strategies where Godot APIs permit them.

`GameCharacterMotor` still owns its own Godot physics callback because it is the concrete physics adapter.

## Architectural rule

The production interaction boundary is:

```text
Source ability = attempt/request interaction
Target reaction = map semantic intent to target-local ability
Target ability  = perform actual target behavior
```

Never replace this with:

```gdscript
if target is GameDoor:
	...
elif target.has_method("activate"):
	...
```

and never encode method/class names in semantic intent IDs.

## Known limits

- World focus/spatial queries remain a world/targeting integration concern.
- Hold and paired interaction data contracts exist, but full asynchronous waits depend on future execution work.
- Concrete door animation, inventory containers, dialogue adapters and similar presentation/game-specific state live outside core.
- Loadout persistence and Inventory System reconciliation remain Stage 5 adapter responsibilities.
- No scenes, `.tres`, `.uid`, `project.godot` or binary resources are added by this API change.
