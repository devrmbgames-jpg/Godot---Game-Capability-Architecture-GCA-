# Stage 3 — Abilities API

Stage 3 adds a data-driven ability layer on top of Foundation, meters and effects. It does not add scenes, `project.godot`, binary resources, input, AI or plugin integrations.

## Object composition

Add `GameAbilities` as a direct child of `GameObjectKernel`. Optional local dependencies are resolved through capabilities:

- `meters.modify` for meter costs;
- `effects.receiver` for effect operations;
- `tags.modify` for execution-owned tags.

The component provides:

- `abilities.owner`;
- `abilities.query`;
- `abilities.activate`;
- `abilities.grant`;
- `abilities.cancel`.

## Definition, grant and execution

`GameAbilityDefinition` is immutable shared configuration. `GameAbilityGrant` stores owner/source-specific state. `GameAbilityExecution` stores one activation lifecycle.

Never store targets, cooldown state, current phase, charges or mutable owner overrides in the shared definition.

## Grant

```gdscript
var abilities := kernel.get_object_context().get_capability(GameCapabilityIds.ABILITIES_GRANT) as GameAbilities
var result := abilities.grant_ability(
	ability_definition,
	item_handle,
	&"item.fire_staff",
	2,
	-1,
	10
)
var grant := result.get_payload() as GameAbilityGrant
```

Keep the returned grant handle. Revoke only that source:

```gdscript
abilities.revoke_grant(grant.get_handle_id(), &"equipment_removed")
```

Other grants of the same ability remain available.

## Query and activation

Create one execution context and request. Query first when UI or AI needs a reason without mutations:

```gdscript
var context := kernel.create_root_execution_context(&"ability.request", "Player requested attack")
var request := GameAbilityActivationRequest.new(
	&"ability.attack.light",
	kernel.get_object_handle(),
	context,
	kernel.get_object_handle()
)
request.set_targets([target_handle])

var query := abilities.query_activation(request)
if query.is_available():
	var result := abilities.activate(request)
else:
	print(query.get_reason_code(), query.get_cooldown_remaining())
```

`query_activation()` does not spend meters, consume charges, start cooldowns, create executions or publish `ability_started`.

## Commit cycle

Activation follows:

```text
request
→ select grant
→ validate capabilities/tags/requirements/cooldown/channels/costs
→ prepare all on-commit costs
→ commit costs atomically
→ consume charge
→ start cooldown
→ occupy channels and grant execution tags
→ execute operations in stable order
→ cleanup owned tags/channels
→ complete, fail or cancel
```

`GameAbilityMeterCost` restores the captured meter value if a later on-commit cost fails. Cancellation refunds only costs explicitly configured with `refund_on_cancel`.

## Scheduler loop

Until Stage 5 supplies simulation time, advance cooldowns from one owner-level tick host:

```gdscript
func _physics_process(delta: float) -> void:
	abilities.advance_time(delta)
	effects.advance_time(delta, kernel.create_root_execution_context(&"simulation.effects_tick"))
	kernel.process_execution_queue()
```

Do not add `_process()` to individual grants, cooldowns or executions.

## Standard extension contracts

- Derive `GameAbilityRequirement` for pure checks.
- Derive `GameAbilityCost` for prepare/commit/rollback/refund behavior.
- Derive `GameAbilityOperation` for small execution actions.
- Use `GameAbilityApplyEffectOperation` to apply an existing `GameEffectDefinition` to normalized target handles.

Custom operations must use capabilities/ports and must not search SceneTree, read input, mutate shared definitions or call sibling features directly.

## Current first-version limits

- Operations are synchronous in this increment; the base contract reserves async/cancel hooks for animation, movement and external wait tokens.
- World spatial targeting remains a Stage 5 port. This increment accepts normalized explicit target handles/point/direction in the activation request.
- Active execution serialization is not implemented; definitions expose the Stage 3 cancel-on-load boundary.
- No `.tres`, scenes, `project.godot` or binary files are included.
