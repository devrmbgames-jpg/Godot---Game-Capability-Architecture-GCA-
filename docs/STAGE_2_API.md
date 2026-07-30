# GCA Stage 2 API

Stage 2 adds attributes, meters, effects, damage and death on top of the Foundation command/event/capability contracts.

## Composition

Add these direct children under `GameObjectKernel` as needed:

- `GameAttributes`
- `GameMeters`
- `GameEffects`
- `GameDamageReceiver`
- `GameDeathPolicy`

They remain sibling-isolated. Dependencies are resolved through capability IDs and local events are routed by the kernel.

## Attributes

`GameAttributes` owns runtime `GameAttributeValue` instances. Definitions are immutable `GameAttributeDefinition` resources.

```gdscript
var attributes: GameAttributes = kernel.get_object_context().get_capability(GameCapabilityIds.ATTRIBUTES_MODIFY) as GameAttributes
var modifier: GameAttributeModifier = attributes.add_modifier(
	&"max_health",
	GameAttributeModifier.Operation.ADD,
	25.0,
	&"equipment.iron_ring"
)
var max_health: float = attributes.get_value(&"max_health")
attributes.remove_modifier(modifier.get_handle_id())
```

Final value is always:

```text
(base + add) * (1.0 + increase)
```

Use `begin_transaction()` / `end_transaction()` around several changes to publish a consistent event batch.

## Meters

Meters store current resources independently from their maximum.

```gdscript
var context: GameExecutionContext = kernel.create_root_execution_context(&"debug.consume_stamina")
meters.modify_current(&"stamina", -20.0, context, &"stamina_spent")
```

Maximum may be constant or sourced from an attribute. Supported maximum-change policies are keep current, keep percentage, adjust by delta and clamp only.

## Effects

Create a `GameEffectDefinition`, then call:

```gdscript
var result: GameCommandResult = effects.apply_effect(
	effect_definition,
	source_handle,
	instigator_handle,
	execution_context
)
```

An effect can grant tags, add attribute modifiers and modify meters. Duration effects are advanced centrally through `GameEffects.advance_time(delta, context)`. Do not add a `_process()` per active effect.

The first implementation supports instant, duration and infinite effects, periodic ticks, duplicate rejection, duration refresh, stack count and independent instances. Runtime effects and modifiers are lightweight `RefCounted` objects rather than nodes.

## Damage

Damage is sent through the Foundation command API:

```gdscript
var request := GameDamageRequest.new(
	source_handle,
	instigator_handle,
	target_handle,
	30.0,
	[&"damage.fire"],
	execution_context
)
var command := GameCommand.new(
	&"damage.apply",
	source_handle,
	target_handle,
	execution_context,
	request,
	GameCapabilityIds.DAMAGE_RECEIVER
)
var result: GameCommandResult = kernel.dispatch_command(command)
```

`GameDamageReceiver` subtracts optional flat defense and changes its configured meter. Negative damage is rejected by `GameDamageRequest`; healing must use a meter operation or effect.

## Death

`GameDeathPolicy` watches `meter_depleted`. It performs a one-time state transition, grants `state.dead`, emits the local `died` event and does not call `queue_free()`.

Explosion, loot, ragdoll or removal should be separate event-driven reactions. A reaction that causes child damage must enqueue a `GameOperation` through the Foundation execution queue instead of recursively calling targets.

## Scheduler loop

Until a world-level simulation service exists, one owner node should advance the effect host:

```gdscript
func _physics_process(delta: float) -> void:
	var context := kernel.create_root_execution_context(&"simulation.effects_tick")
	effects.advance_time(delta, context)
	kernel.process_execution_queue()
```

In Stage 5 this call moves behind the world simulation-time service.

## Snapshot boundary

Definitions are referenced by stable IDs. Runtime handles are never persistent IDs. Snapshot integration should save changed attribute bases, meter currents and persistent effect definition IDs with remaining duration/stacks, then recreate runtime handles on restore.

## Current first-version limits

- Derived attribute strategies and graph validation are reserved for the next Stage 2 increment.
- Effect application validates required pieces before commit, but full generic rollback across arbitrary custom operations is not included.
- Damage mitigation currently ships with replaceable configuration at the receiver boundary and one flat-defense implementation; damage-type-specific policies should be separate strategies.
- No scenes, `.tres`, `project.godot` or binary assets are included in this repository change.
