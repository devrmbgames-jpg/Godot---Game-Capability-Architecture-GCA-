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

For objects that need logical hotbar/action slots, also add `GameAbilityLoadout`. It provides `abilities.loadout` and depends on `abilities.query`.

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

## Ability loadout and logical slots

`GameAbilityLoadout` is optional. It does not own abilities or executions. It only maps logical slots such as `slot.primary`, `slot.secondary`, `slot.mobility` or `slot.quick_1` to concrete runtime grant handles.

This separation is intentional:

```text
Grant          = owner has an ability
Loadout slot   = one grant is assigned to a logical action slot
Input binding  = a player input action activates that logical slot
```

Initial slots use `GameAbilitySlotDefinition`. The referenced ability must already exist in `GameAbilities.initial_abilities`. During initialization the loadout resolves the selected grant and stores the concrete handle.

Runtime systems should bind the exact grant they created:

```gdscript
var grant_result := abilities.grant_ability(
	sword_attack,
	item_handle,
	&"item.sword.instance_17",
	1,
	-1,
	100
)
var grant := grant_result.get_payload() as GameAbilityGrant

var loadout := kernel.get_object_context().get_capability(
	GameCapabilityIds.ABILITIES_LOADOUT
) as GameAbilityLoadout

var binding_result := loadout.bind_grant(
	&"slot.primary",
	grant.get_handle_id(),
	&"item.sword.instance_17",
	100
)
var binding := binding_result.get_payload() as GameAbilitySlotBinding
```

Several sources may bind the same slot. Higher `priority` wins; equal priority uses the newer binding. Lower-priority bindings remain intact.

If the overriding grant is revoked, `resolve_slot()` ignores that stale grant and automatically exposes the next valid binding. This allows equipment/effects to override a base action without manually restoring the old value.

Remove only source-owned state:

```gdscript
loadout.unbind(binding.get_handle_id())
abilities.revoke_grant(grant.get_handle_id(), &"equipment_removed")
```

For a source that owns several slot bindings:

```gdscript
loadout.unbind_source(&"item.sword.instance_17")
```

Ability definitions never contain input actions or keyboard/gamepad buttons.

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

Two additional read-only helpers are available for loadout/UI integration:

```gdscript
abilities.has_grant(grant_handle_id)
abilities.resolve_grant_handle(&"ability.attack.light")
```

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
- Use `GameAbilityLoadout` only when a controlled object needs assignable logical slots.

Custom operations must use capabilities/ports and must not search SceneTree, read input, mutate shared definitions or call sibling features directly.

## Current first-version limits

- Operations are synchronous in this increment; the base contract reserves async/cancel hooks for animation, movement and external wait tokens.
- World spatial targeting remains a Stage 5 port. This increment accepts normalized explicit target handles/point/direction in the activation request.
- Active execution serialization is not implemented; definitions expose the Stage 3 cancel-on-load boundary.
- Loadout bindings are runtime state in this increment; persistence/reconciliation remains a Stage 5 responsibility.
- No `.tres`, scenes, `project.godot` or binary files are included.
