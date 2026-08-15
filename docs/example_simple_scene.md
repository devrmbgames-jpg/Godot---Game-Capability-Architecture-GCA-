# Пошаговый прототип GCA: актуальный API

Этот tutorial собирает небольшую 3D-сцену с Player, Monster, Door, Barrel и Mine на **текущем публичном API GCA**.

Главные маршруты:

```text
Input / AI decision
→ GameControlSource
→ GameControlEndpoint
→ GameAbilityLoadout / GameAbilities
→ Ability Operation
→ world port / InteractionTarget / DamageReceiver / Effects
→ Meters / Tags / DeathPolicy
```

Полные game-specific скрипты находятся в [`example_simple_scene_complete_scripts.md`](./example_simple_scene_complete_scripts.md).

---

## 0. Важные границы текущего API

### Player input не активирует конкретные abilities вручную

Нормальный player path:

```text
InputAction
→ GamePlayerInputSource
→ slot_id
→ GameControlEndpoint
→ GameAbilityLoadout.resolve_slot()
→ grant_handle_id
→ GameAbilities.activate()
```

Поэтому в player root **не нужен** `_unhandled_input()` с `abilities.activate(...)` для attack/dodge/mine/interact.

### Interaction — это ability с обеих сторон

```text
slot.interaction
→ source-owned ability.interact
→ GameInteractionAbilityOperation
→ GameInteractionRequest
→ GameInteractionTarget
→ GameInteractionReaction
→ target-owned ability
```

`GameInteractionOffer` — только semantic/UI/AI description. Он не содержит `ability_id` или `command_id`.

### World integrations идут через `GameWorldContext`

Для статических объектов мира:

```text
GameWorldContext.bind_kernel(kernel)
→ inject world ports
→ initialize kernel
→ register GameObjectHandle
```

World-aware operation получает сервис так:

```gdscript
var targeting_service: GameTargetingService = (
	context.get_world_port(GameWorldPortIds.TARGETING_QUERY)
	as GameTargetingService
)
```

Не передавайте `GameTargetingService` в каждую ability через `activation_payload`.

### Effects в текущем API не являются DamageRequests

`GameEffects.apply_effect()` и `advance_time()` работают с `GameEffectDefinition`.
Периодические `meter_operations` применяются напрямую через `GameMeters.modify_current()`.

То есть текущий Burning example:

```text
GameEffects.apply_effect(burning)
→ status.burning
→ period
→ meter_operations[Health -5]
→ GameMeters
→ GameDeathPolicy, если meter depleted
```

Он **не проходит через `GameDamageReceiver`**. Если проекту нужен combat-aware DoT с resistance/friendly-fire/damage log, это отдельная gameplay operation/adapter поверх текущего Effect API.

---

# 1. Data Studio

Включите:

```text
addons/gca_data_studio/
```

Data Studio создаёт текущие:

```text
GameAttributeDefinition
GameMeterDefinition
GameEffectDefinition
GameAbilityDefinition
```

Категории доступны даже если в проекте ещё нет definitions.

Сложные поля (`requirements`, `costs`, `operations`, effect dictionaries) редактируются стандартным Godot Inspector.

---

# 2. Общие definitions

## 2.1 Attributes

Создайте:

```text
simple.attribute.movement_speed
simple.attribute.max_health
```

Пример:

```text
movement_speed.default_base = 5.0
max_health.default_base     = 100.0
```

Формула runtime attribute остаётся:

```text
(base + add) * (1.0 + increase)
```

## 2.2 Health meter

Создайте `GameMeterDefinition`:

```text
meter_id              = simple.meter.health
initial_policy        = FULL
maximum_policy        = ATTRIBUTE
maximum_attribute_id  = simple.attribute.max_health
minimum               = 0
maximum_change_policy = CLAMP_ONLY
depletion_threshold   = 0
save_current          = true
```

## 2.3 Tags

Для примера:

```text
object.entity.player
object.entity.monster
object.prop.door
object.prop.barrel
object.trap.mine
faction.player
faction.monster
state.open
status.burning
damage.melee
damage.explosion
```

Если `GameTagContainer.reject_unknown_tags == true`, добавьте project-specific tags в используемый `GameTagCatalog`.

## 2.4 Abilities

Создайте:

```text
simple.ability.player.attack
simple.ability.player.dodge
simple.ability.player.place_mine
simple.ability.player.interact
simple.ability.monster.attack
simple.ability.door.open
simple.ability.door.close
```

Operations:

```text
player.attack      → GameAttackOperationSimple
dodge              → GameDodgeOperationSimple
place_mine         → GamePlaceMineOperationSimple
player.interact    → GameInteractionAbilityOperation
monster.attack     → GameAttackOperationSimple
door.open          → GameDoorSetOpenOperationSimple(open = true)
door.close         → GameDoorSetOpenOperationSimple(open = false)
```

Door requirements:

```text
simple.ability.door.open
blocked_owner_tags = [state.open]

simple.ability.door.close
required_owner_tags = [state.open]
```

Это автоматически делает `open` доступным только в закрытом состоянии, а `close` — только в открытом.

## 2.5 Burning

Создайте `GameEffectDefinition`:

```text
effect_id               = simple.effect.burning
duration_policy         = DURATION
duration                = 4.0
period                  = 1.0
execute_period_on_apply = false
stacking_policy         = REFRESH_DURATION
stack_limit             = 1
granted_tags            = [status.burning]
meter_operations        = [{ meter_id = simple.meter.health, delta = -5.0 }]
```

Dictionary key для meter operation в текущем runtime — `meter_id` + `delta`.

---

# 3. World composition

Рекомендуемая сцена:

```text
SimpleScene (Node3D)
├── WorldServices (Node)
│   ├── GameObjectResolver
│   ├── GameSpawnService
│   ├── GameTargetingService
│   ├── GameTimeService
│   ├── GamePersistenceCoordinator
│   └── GameWorldContext
├── LevelGeometry
├── NavigationRegion3D
├── PatrolPoints
├── SpawnedMines
├── Player
├── Monster
├── Door
└── Barrels
```

Настройте ссылки:

```text
GameSpawnService.object_resolver    = GameObjectResolver
GameSpawnService.default_parent     = SpawnedMines
GameTargetingService.object_resolver = GameObjectResolver

GameWorldContext.object_resolver          = GameObjectResolver
GameWorldContext.spawn_service            = GameSpawnService
GameWorldContext.targeting_service        = GameTargetingService
GameWorldContext.time_service             = GameTimeService
GameWorldContext.persistence_coordinator  = GamePersistenceCoordinator
```

`region_streaming_service` можно оставить `null`, если streaming не используется.

## 3.1 Статические GCA objects

Для Player/Monster/Door/Barrels выставьте в Inspector:

```text
GameObjectKernel.auto_initialize = false
```

Это важно: `GameWorldContext.bind_kernel()` принимает только `UNINITIALIZED` kernel, потому что world ports должны быть injected **до** initialization.

В `GameSimpleScene._ready()` bind-ите каждый статический kernel через `world_context.bind_kernel(...)`.

После `bind_kernel()` не вызывайте `object_resolver.register_handle()` второй раз — world context уже регистрирует handle.

## 3.2 Runtime spawn

Для динамических объектов используйте:

```gdscript
GameSpawnService.spawn(...)
GameSpawnService.despawn(...)
```

`spawn()` создаёт сцену, находит direct-child `GameObjectKernel`, инициализирует его, регистрирует handle и возвращает `GameCommandResult` с `GameObjectHandle` в payload.

Для Mine scene настройте identity как ephemeral runtime identity:

```text
GameObjectIdentity.stable_id = ""
GameObjectIdentity.allow_runtime_generated_id = true
```

Тогда каждый spawned instance получит свой `runtime.<instance_id>` и не будет конфликтовать с предыдущей миной. Если мина должна переживать save/load, передавайте `stable_id` в `GameSpawnService.spawn()` из persistence-aware gameplay layer вместо runtime-generated ID.

`despawn()` вызывает resolver policy (`mark_unresolved` или `invalidate_permanently`) и освобождает root.

### Текущая оговорка SpawnService

`GameWorldContext.bind_kernel()` inject-ит world ports. Текущий `GameSpawnService.spawn()` самостоятельно инициализирует kernel, но **не inject-ит `GameWorldContext.get_world_ports()`**.

Поэтому в этом учебном Mine example world dependencies, нужные runtime-мине после spawn, передаются явно (`targeting_service`, `spawn_service`). Не предполагайте, что `spawned_mine.context.get_world_port(...)` уже заполнен.

---

# 4. Player composition

```text
Player (CharacterBody3D)
├── CollisionShape3D
├── Camera...
├── GameObjectKernel (auto_initialize = false)
│   ├── GameObjectIdentity
│   ├── GameTagContainer
│   ├── GameAttributes
│   ├── GameMeters
│   ├── GameEffects
│   ├── GameAbilities
│   ├── GameAbilityLoadout
│   ├── GameControlArbiter
│   ├── GameControlEndpoint
│   ├── GameCharacterMotor
│   ├── GameInteractionSource
│   ├── GameDamageReceiver
│   ├── GameDeathPolicy
│   └── GamePresentationCueReceiver
└── GamePlayerInputSource
```

## 4.1 Base grants

В `GameAbilities.initial_abilities` добавьте четыре player abilities. `GameAbilities` выдаст grants во время initialization.

## 4.2 Loadout

В `GameAbilityLoadout.initial_slots` создайте `GameAbilitySlotDefinition`:

```text
slot.primary      → simple.ability.player.attack
slot.mobility     → simple.ability.player.dodge
slot.utility_1    → simple.ability.player.place_mine
slot.interaction  → simple.ability.player.interact
```

Initial slot definition не grant-ит ability; она должна уже присутствовать в `GameAbilities.initial_abilities` или быть выдана другим source.

## 4.3 Input bindings

В `GamePlayerInputSource.ability_input_bindings`:

```text
attack      → slot.primary
interact    → slot.interaction
dodge       → slot.mobility
place_mine  → slot.utility_1
```

InputMap, например:

```text
attack     = Mouse1
interact   = E
dodge      = Space
place_mine = Q
```

Не добавляйте эти actions в `GameAbilityDefinition`.

## 4.4 Control attach

Root player script только подключает source:

```gdscript
player_input_source.set_execution_context_factory(
	func(cause: StringName, label: String) -> GameExecutionContext:
		return kernel.get_object_context().create_root_execution_context(cause, label)
)

var result := player_input_source.attach(control_endpoint, control_arbiter)
if result.is_success():
	player_input_source.request_control()
```

Attack/dodge/place-mine больше не обрабатываются в `_unhandled_input()`.

## 4.5 Local scheduler

Локальное продвижение времени остаётся допустимым:

```gdscript
func _physics_process(delta: float) -> void:
	abilities.advance_time(delta)
	effects.advance_time(
		delta,
		kernel.get_object_context().create_root_execution_context(
			&"simple.player.effects_tick",
			"Player effects tick"
		)
	)
	kernel.process_execution_queue()
```

---

# 5. Attack operation

`GameAttackOperationSimple` получает всё необходимое из activation request и owner context:

```text
request.owner_handle
→ owner root Node3D
→ owner context
→ GameWorldPortIds.TARGETING_QUERY
→ GameTargetingService
```

Не используйте payload `actor_node` / `targeting_service`.

Target query:

```gdscript
var query := targeting_service.query_sphere(
	actor.global_position,
	attack_radius,
	GameCapabilityIds.DAMAGE_RECEIVER,
	required_tags,
	[source_handle.get_stable_id()]
)
```

Каждой цели отправляется `GameDamageRequest` через `GameDamageReceiver.apply_damage()`.

---

# 6. Dodge operation

Текущий `GameCharacterMotor` не предоставляет готовую timed dash API на несколько метров.

Поэтому complete companion использует **prototype fallback**: operation получает owner root как `CharacterBody3D` и делает один collision-aware `move_and_collide()`.

Это устраняет callback payload, но не является production dodge. Production evolution — отдельный movement/control adapter с временным ownership и cleanup.

---

# 7. Mine placement

`GamePlaceMineOperationSimple` получает:

```text
owner_context.get_world_port(GameWorldPortIds.SPAWN_REQUEST)
→ GameSpawnService
```

Затем:

```text
spawn_service.spawn(...)
→ GameCommandResult.payload = GameObjectHandle
→ handle.get_root() as GameMineSimple
→ assign owner/instigator + explicit runtime dependencies
→ arm_after_delay()
```

Не передавайте `spawn_mine_callable` через activation payload.

---

# 8. Monster

Monster использует тот же control endpoint.

Для атаки:

```gdscript
ai_control_source.use_ability(
	&"simple.ability.monster.attack",
	[],
	execution_context
)
```

Не вызывайте `monster.abilities.activate()` напрямую из AI state machine и не передавайте actor/targeting payload.

---

# 9. Interaction / Door

Door composition:

```text
Door
└── GameObjectKernel (auto_initialize = false)
    ├── GameObjectIdentity
    ├── GameTagContainer
    ├── GameAbilities
    └── GameInteractionTarget
```

`GameAbilities.initial_abilities` содержит door.open и door.close.

`GameInteractionTarget.reactions`:

```text
open:  offer=simple.door.open  intent=open  verb=verb.open  ability=simple.ability.door.open
close: offer=simple.door.close intent=close verb=verb.close ability=simple.ability.door.close
```

Обе reactions могут быть `default_candidate = true`: availability определяется requirements самих abilities.

Core interaction не делает spatial focus автоматически. Sensor/raycast/targeting adapter проекта должен вызвать:

```gdscript
interaction_source.set_focus(target_handle, execution_context)
```

после выбора target.

---

# 10. Damage и Death

Damage path:

```text
GameDamageRequest
→ GameDamageReceiver.apply_damage()
→ GameMeters
→ meter_depleted
→ GameDeathPolicy
```

`GameDeathPolicy` имеет signal:

```gdscript
signal died(execution_context: GameExecutionContext)
```

Player/Monster/Barrel/Mine могут подключаться к нему напрямую. Не нужно polling `health == 0` и не нужно угадывать имя death event.

---

# 11. Barrel

Barrel получает targeting через injected world port:

```gdscript
var targeting_service := context.get_world_port(
	GameWorldPortIds.TARGETING_QUERY
) as GameTargetingService
```

Для удаления:

```gdscript
var spawn_service := context.get_world_port(
	GameWorldPortIds.DESPAWN_REQUEST
) as GameSpawnService
spawn_service.despawn(barrel_handle, &"exploded", true)
```

Guard `_exploded` ставьте до radial damage.

---

# 12. Mine и Burning

Для spawned mine example явно назначаются:

```text
owner_handle
instigator_handle
targeting_service
spawn_service
burning_effect
```

После successful explosion hit:

```gdscript
var target_effects := target_context.get_capability(
	GameCapabilityIds.EFFECTS_RECEIVER
) as GameEffects

target_effects.apply_effect(
	burning_effect,
	mine_handle,
	effective_instigator,
	execution_context
)
```

Это текущая сигнатура Effect API.

---

# 13. Runtime registration lifecycle

В текущем API существуют:

```text
GameObjectResolver.mark_unresolved(stable_id)
GameObjectResolver.invalidate_permanently(stable_id)
GameSpawnService.despawn(handle, reason, permanent)
```

Для runtime object, созданного `GameSpawnService`, используйте `despawn()` вместо неопределённого “unregister API”.

---

# 14. Проверочный порядок

```text
1. Data Studio показывает creation categories в пустом content.
2. Resolver назначен SpawnService и TargetingService.
3. World services назначены GameWorldContext.
4. Static kernels имеют auto_initialize=false.
5. GameWorldContext.bind_kernel() успешно bind-ит static objects.
6. Player movement идёт через control endpoint.
7. attack InputAction активирует slot.primary.
8. Attack operation получает targeting через world port.
9. DamageRequest уменьшает Health через DamageReceiver.
10. DeathPolicy.died срабатывает на depletion.
11. AI attack проходит через GameMockAIControlSource.use_ability().
12. Interaction focus установлен sensing adapter-ом.
13. E активирует slot.interaction → generic interact ability.
14. Door default interaction выбирает open/close по ability requirements.
15. Mine identity разрешает runtime-generated ID.
16. PlaceMine operation использует GameSpawnService.
17. Spawned mine получает owner/instigator и explicit runtime dependencies.
18. Burning применяется через GameEffects.apply_effect().
19. Burning period изменяет Health через meter_operations.
20. Despawn проходит через GameSpawnService.despawn().
```

---

# 15. Главное правило

```text
Input / AI decision
→ intent / ability slot
→ ability activation
→ operation
→ object/world capability
→ state mutation
→ presentation
```

Не возвращайтесь к `Input handler → hardcoded ability ID → Dictionary с Node/Callable/service`, если dependency уже выражен через owner context, capability, world port, grant/loadout или semantic interaction request.
