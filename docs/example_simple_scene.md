# Пошаговый прототип GCA: персонаж, монстр, дверь, бочка и мина

Этот документ показывает, как с нуля собрать небольшую **играбельную 3D-сцену-прототип** на базе GCA. Цель инструкции — не просто показать отдельные классы, а провести через полный рабочий цикл:

```text
ввод игрока / решение AI
→ GameControl...
→ GameAbilities
→ Interaction / Targeting
→ GameDamageRequest / GameEffects
→ GameMeters
→ смерть / реакция объекта
→ Presentation
```

После выполнения инструкции получится арена, в которой:

- игрок ходит, атакует, уклоняется, взаимодействует и устанавливает мины;
- монстр патрулирует область, замечает игрока, преследует и атакует его;
- игрок и монстр имеют здоровье и получают урон через единый GCA damage pipeline;
- дверь открывается и закрывается через generic interaction ability и target-owned abilities;
- бочка получает урон, взрывается и может вызвать цепную реакцию;
- мина устанавливается игроком, вооружается, может быть уничтожена уроном, взрывается и накладывает `Горение`;
- все игровые объекты имеют стабильные GCA identity/handles;
- динамически созданные объекты регистрируются в сервисах мира;
- эффекты и способности реально обновляются во времени.

> Важно: GCA предоставляет архитектурные примитивы — объекты, capability, abilities, effects, damage, control, interaction, targeting и т. д. Конкретное поведение вроде «сделать выпад на 4 метра», «патрулировать эти три точки» или «создать сцену мины» остаётся игровой логикой вашего проекта и реализуется небольшими glue-скриптами.

---

## 0. Что будем использовать из GCA

Основные классы, с которыми вы столкнётесь:

- `GameObjectKernel` — ядро игрового объекта;
- `GameObjectIdentity` — stable ID и definition ID объекта;
- `GameObjectContext` — runtime-контекст объекта и доступ к capability;
- `GameObjectHandle` — безопасная ссылка на игровой объект;
- `GameObjectResolver` — разрешение stable ID/handle в мире;
- `GameTagContainer` — теги объекта;
- `GameAttributes` — вычисляемые атрибуты;
- `GameMeters` — изменяемые шкалы, например здоровье;
- `GameAbilities` — выдача и активация способностей;
- `GameAbilityLoadout` — логические ability slots;
- `GameEffects` — эффекты и статусы;
- `GameDamageReceiver` — входная точка получения урона;
- `GameDamageRequest` — стандартный запрос на нанесение урона;
- `GameDeathPolicy` — переход объекта в состояние смерти;
- `GameControlArbiter` — владелец control channels;
- `GameControlEndpoint` — endpoint управления;
- `GamePlayerInputSource` — источник управления от игрока;
- `GameMockAIControlSource` — простой источник управления для AI-прототипа;
- `GameCharacterMotor` — движение персонажа;
- `GameInteractionSource` — инициатор semantic interaction requests;
- `GameInteractionTarget` — объект, принимающий interaction requests;
- `GameInteractionRequest` — запрос с optional semantic intent;
- `GameInteractionReaction` — target-local mapping `intent → ability`;
- `GameInteractionOffer` — semantic описание доступного взаимодействия для UI/AI;
- `GameInteractionAbilityOperation` — generic operation «взаимодействовать с чем-то»;
- `GameTargetingService` — выбор GCA-целей по миру;
- `GameExecutionContext` — цепочка причин/операций;
- `GamePresentationCueReceiver` — presentation/reaction слой;
- `GameCommandResult` — стандартный результат команды.

### GCA Data Studio

В репозитории находится редакторская утилита:

```text
res://addons/gca_data_studio/
```

Для data-driven частей прототипа используйте **GCA Data Studio**, а не создавайте все `.tres` вручную.

Через Data Studio удобно создавать и редактировать определения:

- атрибутов;
- meters;
- abilities;
- effects;
- связанных data-ресурсов GCA.

После создания ресурса сохраните его в `res://content/...` и назначьте соответствующему runtime-компоненту через Inspector.

В этой инструкции Data Studio используется для **определений**, а GDScript — только для поведения конкретной игры.

---

# 1. Рекомендуемая структура файлов

Создайте каталог:

```text
res://content/gameplay/simple_scene/
```

Рекомендуемая структура:

```text
res://content/gameplay/simple_scene/
├── world/
│   ├── simple_scene.tscn
│   └── game_simple_scene.gd
│
├── player/
│   ├── ent_player_simple.tscn
│   └── game_player_simple.gd
│
├── monster/
│   ├── ent_monster_simple.tscn
│   └── game_monster_simple.gd
│
├── door/
│   ├── prop_door_simple.tscn
│   ├── game_door_simple.gd
│   └── game_door_set_open_operation_simple.gd
│
├── barrel/
│   ├── prop_barrel_simple.tscn
│   └── game_barrel_simple.gd
│
├── mine/
│   ├── prop_mine_simple.tscn
│   └── game_mine_simple.gd
│
├── abilities/
│   ├── game_attack_operation_simple.gd
│   ├── game_dodge_operation_simple.gd
│   └── game_place_mine_operation_simple.gd
│
└── shared/
    ├── attributes/
    ├── meters/
    ├── abilities/
    └── effects/
```

Названия приведены как пример. Важно сохранять разделение:

- **definition/data** — `.tres`;
- **runtime GCA-компоненты** — дочерние узлы `GameObjectKernel`;
- **game-specific orchestration** — скрипт корневого узла сцены.

---

# 2. Сначала создаём общие GCA-данные

Не начинайте с персонажа. Сначала создайте набор данных, который затем смогут переиспользовать игрок, монстр, дверь, бочка и мина.

## 2.1. Атрибуты

Через GCA Data Studio создайте как минимум:

```text
simple.attribute.movement_speed
simple.attribute.max_health
simple.attribute.attack_damage
```

Для прототипа можно использовать значения:

```text
movement_speed = 5.0
max_health     = 100.0
attack_damage  = 25.0
```

GCA вычисляет итоговый атрибут по модели:

```text
(base + add) * (1.0 + increase)
```

Поэтому скорость, здоровье и урон в дальнейшем можно модифицировать эффектами без изменения кода персонажа.

## 2.2. Health meter

Создайте meter:

```text
simple.meter.health
```

Настройте его так, чтобы:

- максимум зависел от `simple.attribute.max_health` или соответствовал ему;
- начальное значение было полным (`FULL`);
- состояние `0` считалось depletion.

Идея:

```text
MaxHealth attribute = 100
Health meter        = 100 / 100
```

Атрибут отвечает на вопрос **«сколько максимум?»**, meter — **«сколько сейчас?»**.

## 2.3. Теги

Для простого прототипа заранее договоритесь о тегах:

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
status.invulnerable

damage.melee
damage.explosion
damage.fire
```

Тег сам по себе ничего «магически» не делает. Например, наличие `status.invulnerable` станет неуязвимостью только тогда, когда ваша damage policy/receiver действительно проверяет этот тег и отклоняет урон.

Для двери `state.open` используется обычными ability requirements:

```text
door.open  blocked_owner_tags  = [state.open]
door.close required_owner_tags = [state.open]
```

Так доступность interaction reaction вычисляется Ability System, а не ручным переключением offers.

## 2.4. Ability definitions

Через Data Studio создайте:

```text
simple.ability.player.attack
simple.ability.player.dodge
simple.ability.player.place_mine
simple.ability.player.interact
simple.ability.monster.attack
simple.ability.door.open
simple.ability.door.close
```

Для каждой ability definition назначьте соответствующую operation/game-specific реализацию.

Для прототипа разумны такие параметры:

```text
Player Attack:
    damage: 25
    range: 2.0 m
    cooldown: 0.45 s

Player Dodge:
    distance: 4.0 m
    duration: 0.22 s
    cooldown: 0.8 s

Place Mine:
    cooldown: 2.0 s

Player Interact:
    operation: GameInteractionAbilityOperation

Monster Attack:
    damage: 15
    range: 1.8 m
    cooldown: 1.0 s

Door Open:
    blocked_owner_tags = [state.open]
    operation = GameDoorSetOpenOperationSimple(open = true)

Door Close:
    required_owner_tags = [state.open]
    operation = GameDoorSetOpenOperationSimple(open = false)
```

Точные поля game-specific operations зависят от реализации. `required_owner_tags` и `blocked_owner_tags` — поля `GameAbilityDefinition`.

## 2.5. Эффект «Горение»

Создайте effect definition:

```text
simple.effect.burning
```

Рекомендуемое поведение:

```text
duration = 4.0 s
period   = 1.0 s
fire damage per tick = 5
runtime tag = status.burning
```

Лучше проводить периодический урон не прямым изменением health meter, а через тот же damage pipeline:

```text
Burning tick
→ GameDamageRequest
→ GameDamageReceiver
→ Health meter
→ DeathPolicy
```

Так melee, explosion и fire damage проходят через одну точку правил.

---

# 3. Основная сцена

Создайте:

```text
res://content/gameplay/simple_scene/world/simple_scene.tscn
```

## 3.1. Дерево сцены

Минимальная структура:

```text
SimpleScene (Node3D)
├── WorldServices (Node)
│   ├── GameObjectResolver
│   └── GameTargetingService
│
├── LevelGeometry (Node3D)
│   └── Floor (StaticBody3D)
│       ├── MeshInstance3D
│       └── CollisionShape3D
│
├── NavigationRegion3D
│
├── PatrolPoints (Node3D)
│   ├── PointA (Marker3D)
│   ├── PointB (Marker3D)
│   └── PointC (Marker3D)
│
├── SpawnedMines (Node3D)
├── Player (instance ent_player_simple.tscn)
├── Monster (instance ent_monster_simple.tscn)
├── Door (instance prop_door_simple.tscn)
├── Barrels (Node3D)
│   ├── Barrel01
│   └── Barrel02
│
└── HUD (CanvasLayer)
```

## 3.2. Не делайте пол только MeshInstance3D

У пола обязательно должен быть физический body и collision:

```text
Floor (StaticBody3D)
├── MeshInstance3D
└── CollisionShape3D
```

Иначе персонажи будут визуально находиться над «полом», который физически не существует.

## 3.3. Collision layers

Для прототипа можно договориться так:

```text
Layer 1 — World
Layer 2 — Player
Layer 3 — Monster
Layer 4 — Damageable / Interactable props
Layer 5 — Hazard / Trigger
```

Это не требование GCA, а удобная схема проекта.

Проверяйте одновременно:

- `collision_layer` объекта;
- `collision_mask` Area/CharacterBody;
- monitoring у `Area3D`;
- наличие `CollisionShape3D`.

## 3.4. World services

`GameObjectResolver` и `GameTargetingService` относятся к миру, поэтому держите их в основной сцене и **передавайте ссылки дочерним объектам явно**.

Не делайте внутри мины или монстра:

```gdscript
get_parent().get_parent().find_child(...)
```

Основная сцена знает своих детей и назначает зависимости напрямую.

Дочерние сцены сообщают наверх через signals.

## 3.5. Регистрация GCA-объектов

После появления объекта в дереве получите его context и handle:

```gdscript
var context: GameObjectContext = kernel.get_object_context()
var handle: GameObjectHandle = context.get_object_handle()
object_resolver.register_handle(handle)
```

Нужно регистрировать как статические, так и динамические объекты, если world service должен уметь их разрешать.

Особенно важно для:

- Player;
- Monster;
- Door;
- Barrel;
- Mine.

При удалении динамической мины обеспечьте симметричное снятие регистрации согласно API resolver вашего текущего GCA.

## 3.6. Динамические мины

`SpawnedMines` нужен как явный контейнер:

```text
SimpleScene
└── SpawnedMines
```

Когда ability игрока создаёт мину, основная сцена или специальный spawn service должен:

1. instantiate `prop_mine_simple.tscn`;
2. добавить её в `SpawnedMines`;
3. передать owner/instigator handle;
4. передать `GameObjectResolver`;
5. передать `GameTargetingService`;
6. дождаться готовности `GameObjectKernel`;
7. зарегистрировать handle мины;
8. вызвать `arm()` или разрешить мине вооружиться самой.

Это предотвращает типичную ошибку: мина существует визуально, но не связана с сервисами мира и потому никого не находит.

## 3.7. Navigation

Для монстра добавьте `NavigationRegion3D` и запеките navmesh.

Проверьте, что:

- пол входит в навигационную геометрию;
- Player и Monster стоят на navmesh;
- двери/стены учитываются согласно вашей навигационной схеме;
- patrol points находятся на доступной области.

---

# 4. Сцена персонажа

Создайте:

```text
res://content/gameplay/simple_scene/player/ent_player_simple.tscn
```

## 4.1. Дерево узлов

```text
Player (CharacterBody3D)
├── Visual (Node3D / MeshInstance3D)
├── CollisionShape3D
├── CameraPivot (Node3D)
│   └── SpringArm3D
│       └── Camera3D
├── MinePlacementMarker (Marker3D)
│
├── GameObjectKernel
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
│
└── GamePlayerInputSource
```

Главный принцип:

```text
Player root
→ координирует
GameObjectKernel children
→ предоставляют capability
```

Не заставляйте capability-узлы искать родителя и вызывать его методы.

---

## 4.2. Identity и теги игрока

В `GameObjectIdentity` задайте, например:

```text
stable_id     = simple.player
definition_id = simple.entity.player
```

В `GameTagContainer`:

```text
object.entity.player
faction.player
```

Если в будущем будет несколько игроков, не используйте один и тот же runtime stable ID для каждого экземпляра.

---

## 4.3. Здоровье игрока

В `GameAttributes` назначьте definition:

```text
simple.attribute.max_health
```

В `GameMeters` назначьте:

```text
simple.meter.health
```

В сцене обязательно должен присутствовать `GameDamageReceiver`.

Без него объект может иметь красивый health meter, но запросы targeting по capability `GameCapabilityIds.DAMAGE_RECEIVER` не будут считать его damageable-целью.

Также добавьте `GameDeathPolicy`.

Рабочий путь:

```text
GameDamageRequest(25)
→ GameDamageReceiver
→ simple.meter.health: 100 → 75
→ если 0
→ GameDeathPolicy
```

Не уменьшайте здоровье обычной атаки так:

```gdscript
# Плохо для боевого pipeline
health -= damage
```

Проводите боевой урон через `GameDamageReceiver`.

---

## 4.4. Контроллер игрока

`GamePlayerInputSource` подключите к:

- `GameControlEndpoint`;
- `GameControlArbiter`.

Каркас подключения:

```gdscript
func _attach_player_control() -> void:
    if kernel == null:
        return
    if kernel.get_object_context() == null:
        return

    player_input_source.set_execution_context_factory(
        func(cause: StringName, label: String) -> GameExecutionContext:
            return kernel.get_object_context().create_root_execution_context(cause, label)
    )

    var result: GameCommandResult = player_input_source.attach(
        control_endpoint,
        control_arbiter
    )

    if result.is_success():
        player_input_source.request_control()
```

Для обычного player input достаточно каналов:

```text
movement
abilities
```

Interaction-кнопка проходит через ability channel как обычный логический slot. Отдельный target-specific input path не нужен.

Если временная способность забрала movement channel, после завершения она должна его освободить, чтобы arbiter восстановил предыдущего владельца.

---

## 4.5. Движение и input bindings игрока

Для движения используйте `GameCharacterMotor` через control pipeline.

В `GameCharacterMotor` укажите:

```text
speed_attribute_id = simple.attribute.movement_speed
```

Тогда изменение movement speed эффектом автоматически отражается на движении без переписывания player script.

Пример InputMap:

```text
move_forward  = W
move_back     = S
move_left     = A
move_right    = D
interact      = E
attack        = Mouse1
dodge         = Space
place_mine    = Q
```

`GamePlayerInputSource.ability_input_bindings` должен связывать физический input с логическими slots, например:

```text
attack      → slot.primary
interact    → slot.interaction
dodge       → slot.mobility
place_mine  → slot.utility_1
```

А `GameAbilityLoadout` уже связывает slot с конкретным runtime grant. Для `slot.interaction` базовый grant — `simple.ability.player.interact`.

Названия action можно выбрать свои, но ability definition не должна знать кнопку.

---

## 4.6. Runtime scheduler игрока

Abilities и Effects должны обновляться во времени.

В корневом player script добавьте цикл уровня объекта:

```gdscript
func _physics_process(delta: float) -> void:
    if abilities != null:
        abilities.advance_time(delta)

    if effects != null and kernel != null and kernel.get_object_context() != null:
        var execution_context: GameExecutionContext = (
            kernel.get_object_context().create_root_execution_context(
                &"simple.player.tick",
                "Simple player scheduler"
            )
        )
        effects.advance_time(delta, execution_context)

    if kernel != null:
        kernel.process_execution_queue()
```

Этот scheduler намеренно остаётся локальной ответственностью owner/subscene. GCA не требует одного глобального тика: локальный цикл удобен для профилирования, изоляции тяжёлых сущностей и project-specific стратегии исполнения.

Если забыть `effects.advance_time()`, периодический эффект `Горение` может быть добавлен, но его duration/periodic logic не будет нормально продвигаться.

---

# 5. Абилка игрока: Атака

## 5.1. Definition

В Data Studio создайте:

```text
simple.ability.player.attack
```

Добавьте custom operation, например:

```text
GameAttackOperationSimple
```

Operation отвечает за игровое действие «найти цели и отправить им damage request».

## 5.2. Активация ability

Обычный helper выглядит так:

```gdscript
func activate_ability(ability_id: StringName) -> GameCommandResult:
    var context: GameObjectContext = kernel.get_object_context()
    if context == null:
        return GameCommandResult.invalid_target("Player context is unresolved.")

    var execution_context: GameExecutionContext = (
        context.create_root_execution_context(
            &"simple.player.ability",
            "Player ability activation"
        )
    )

    var request := GameAbilityActivationRequest.new(
        ability_id,
        context.get_object_handle(),
        execution_context,
        context.get_object_handle()
    )

    return abilities.activate(request)
```

Для production player input этот helper обычно не нужен: `GamePlayerInputSource → slot → GameControlEndpoint → GameAbilities` уже выполняет activation. Helper полезен для scripted/game-specific glue.

## 5.3. Поиск цели

Для простого melee-прототипа operation может использовать `GameTargetingService.query_sphere()`.

Каркас:

```gdscript
var query: Dictionary = targeting_service.query_sphere(
    actor.global_position,
    attack_radius,
    GameCapabilityIds.DAMAGE_RECEIVER,
    required_tags,
    excluded_ids
)
```

Для атаки игрока можно потребовать:

```text
faction.monster
```

или использовать отдельные правила faction/friendly fire.

## 5.4. Нанесение урона

Для каждой найденной цели получите capability:

```gdscript
var receiver: GameDamageReceiver = target_context.get_capability(
    GameCapabilityIds.DAMAGE_RECEIVER
) as GameDamageReceiver
```

Создайте запрос:

```gdscript
var damage_tags: Array[StringName] = [
    &"damage.melee"
]

var request := GameDamageRequest.new(
    source_handle,
    instigator_handle,
    target_handle,
    attack_damage,
    damage_tags,
    execution_context
)

receiver.apply_damage(request)
```

Таким образом ability не знает внутреннее устройство здоровья монстра.

---

# 6. Абилка игрока: Уклонение

Создайте в Data Studio:

```text
simple.ability.player.dodge
```

## 6.1. Что должна делать operation

Для первого прототипа:

1. определить направление движения игрока;
2. временно перехватить movement control с большим priority;
3. начать короткое перемещение/рывок;
4. при необходимости добавить временный статус `status.invulnerable`;
5. дождаться окончания dodge duration;
6. убрать статус;
7. освободить временное управление;
8. позволить `GameControlArbiter` вернуть канал `GamePlayerInputSource`.

Схема:

```text
PlayerInput owns movement
        ↓
Dodge ability временно preempt movement
        ↓
рывок
        ↓
release movement
        ↓
PlayerInput снова владеет movement
```

## 6.2. Не оставляйте control channel захваченным

Очень частая ошибка:

```text
уклонение сработало один раз
→ после этого персонаж больше не ходит
```

Причина — временный source/operation не освободил канал.

## 6.3. Неуязвимость

Если используете `status.invulnerable`, добавьте проверку в правила получения урона.

Просто добавить тег недостаточно: damage policy должна отклонять incoming `GameDamageRequest` при этом теге.

Для самого первого прототипа можно сначала сделать dodge **без i-frames**, убедиться, что control ownership корректно возвращается, и только затем добавить неуязвимость.

---

# 7. Абилка игрока: Установка мины

Создайте:

```text
simple.ability.player.place_mine
```

## 7.1. MinePlacementMarker

На player scene уже есть:

```text
MinePlacementMarker (Marker3D)
```

Разместите его примерно в 1–1.5 метрах перед персонажем.

## 7.2. Не заставляйте ability знать всю Main Scene

Хороший вариант:

```text
PlaceMineOperation
→ emit/request spawn mine
→ Player или MainScene получает запрос
→ MainScene создаёт mine instance
```

Либо operation получает заранее внедрённый spawn service/callable.

Не делайте поиск основной сцены через длинную цепочку `get_parent()`.

## 7.3. Что передать созданной мине

При создании передайте:

```text
owner_handle      = handle игрока
instigator_handle = handle игрока
targeting_service = world targeting service
object_resolver   = world resolver
```

После добавления в дерево зарегистрируйте GCA handle мины.

## 7.4. Защита от мгновенного самоподрыва

Мина должна сначала быть невооружённой:

```text
spawn
→ 0.35 s arming delay
→ trigger enabled
→ armed = true
```

Также исключайте `owner_handle` из explosion/trigger rules, если дизайн не предусматривает self damage.

---

# 8. Монстр

Создайте:

```text
res://content/gameplay/simple_scene/monster/ent_monster_simple.tscn
```

## 8.1. Дерево узлов

```text
Monster (CharacterBody3D)
├── Visual
├── CollisionShape3D
├── NavigationAgent3D
│
├── GameObjectKernel
│   ├── GameObjectIdentity
│   ├── GameTagContainer
│   ├── GameAttributes
│   ├── GameMeters
│   ├── GameEffects
│   ├── GameAbilities
│   ├── GameControlArbiter
│   ├── GameControlEndpoint
│   ├── GameCharacterMotor
│   ├── GameDamageReceiver
│   ├── GameDeathPolicy
│   └── GamePresentationCueReceiver
│
└── GameMockAIControlSource
```

Если Monster/NPC должен взаимодействовать с миром, добавьте ему `GameInteractionSource` и generic interaction ability. Если он сам является interactable NPC, можно одновременно добавить `GameInteractionTarget`: source и target используют разные exclusive capabilities и не конфликтуют.

## 8.2. Identity и здоровье

Пример:

```text
stable_id     = simple.monster.001
definition_id = simple.entity.monster
```

Tags:

```text
object.entity.monster
faction.monster
```

Для прототипа:

```text
MaxHealth = 100
Health    = 100 / 100
```

Обязательно добавьте `GameDamageReceiver`, иначе attack ability игрока, фильтрующая цели через `DAMAGE_RECEIVER`, не увидит монстра.

---

## 8.3. Контроллер монстра

Подключите `GameMockAIControlSource` к тем же control primitives:

```gdscript
var result: GameCommandResult = ai_control_source.attach(
    control_endpoint,
    control_arbiter
)

if result.is_success():
    ai_control_source.request_control()
```

AI и Player используют одну архитектуру управления. Разница только в источнике intent.

---

## 8.4. Состояния AI

Для прототипа достаточно четырёх состояний:

```gdscript
enum State {
    PATROL,
    CHASE,
    ATTACK,
    DEAD,
}
```

Рекомендуемые дистанции:

```text
detect_distance = 10.0
lose_distance   = 14.0
attack_distance = 1.8
```

`lose_distance` специально больше `detect_distance`: это hysteresis, чтобы AI не переключался между PATROL/CHASE каждый кадр на границе радиуса.

---

## 8.5. Патрулирование определённой области

В Main Scene есть:

```text
PatrolPoints
├── PointA
├── PointB
└── PointC
```

Main Scene передаёт массив точек монстру.

Монстр не должен искать их через родителей.

Алгоритм:

```text
PATROL
→ выбрать текущую Marker3D
→ NavigationAgent3D.target_position = marker.global_position
→ двигаться к next_path_position
→ дошёл
→ выбрать следующую точку
```

Для случайного патруля можно выбирать следующую точку случайно, а для предсказуемого — циклически:

```text
A → B → C → A
```

## 8.6. Движение через AI control source

Когда есть направление:

```gdscript
var execution_context: GameExecutionContext = (
    kernel.get_object_context().create_root_execution_context(
        &"simple.monster.move",
        "Monster movement"
    )
)

ai_control_source.move(direction, 1.0, execution_context)
```

Когда надо остановиться:

```gdscript
ai_control_source.stop(execution_context)
```

Не записывайте `velocity` одновременно из AI script и `GameCharacterMotor`, иначе получите две конкурирующие системы движения.

---

## 8.7. Преследование игрока

Main Scene передаёт монстру ссылку/handle игрока.

Логика:

```text
если player distance <= detect_distance
    PATROL → CHASE

если CHASE
    NavigationAgent target = player position

если distance <= attack_distance
    CHASE → ATTACK

если distance > lose_distance
    CHASE → PATROL
```

Для полноценного production AI позже можно заменить этот state machine на GOAP/другой planner, не меняя GCA-контракты движения и abilities.

---

# 9. Абилка монстра: Атака

Создайте:

```text
simple.ability.monster.attack
```

Используйте тот же принцип, что у player attack:

```text
AI принимает решение атаковать
→ GameAbilities.activate()
→ attack operation
→ targeting
→ GameDamageRequest
→ Player.GameDamageReceiver
```

Для target rules монстра используйте `faction.player`.

Нельзя делать:

```gdscript
player.health -= 15
```

Монстр не должен знать, где игрок хранит здоровье.

При состоянии `ATTACK` AI:

1. останавливает движение;
2. активирует `simple.ability.monster.attack`;
3. получает `GameCommandResult`;
4. cooldown ability предотвращает спам;
5. если игрок вышел из attack distance — снова `CHASE`.

---

# 10. Смерть игрока и монстра

Смерть — отдельное состояние, а не просто `health == 0`.

Когда `GameDeathPolicy` сообщает о смерти:

для Player:

```text
stop/release player control
→ запретить abilities
→ presentation cue
→ показать Game Over / restart
```

для Monster:

```text
State = DEAD
→ stop AI control
→ больше не patrol/chase/attack
→ presentation cue
→ удалить позже или оставить corpse
```

Проверяйте переход смерти **один раз**, а не каждый `_physics_process()`.

---

# 11. Сцена двери

Создайте:

```text
res://content/gameplay/simple_scene/door/prop_door_simple.tscn
```

## 11.1. Дерево

```text
Door (AnimatableBody3D)
├── Hinge (Node3D)
│   ├── MeshInstance3D
│   └── CollisionShape3D
│
└── GameObjectKernel
    ├── GameObjectIdentity
    ├── GameTagContainer
    ├── GameAbilities
    └── GameInteractionTarget
```

Поворот `Hinge`, например:

```text
closed = 0°
open   = 95°
```

`GameAbilities.initial_abilities` двери:

```text
simple.ability.door.open
simple.ability.door.close
```

---

## 11.2. Interaction: инициатор выражает желание, цель исполняет свою ability

У Player/NPC есть generic source ability:

```text
simple.ability.player.interact
└── GameInteractionAbilityOperation
```

Она означает только:

> «Я хочу взаимодействовать с чем-то».

Она не знает, что перед ней `Door`, `Chest`, `NPC`, и не вызывает произвольные методы цели.

У двери есть `GameInteractionReaction`:

```text
Open reaction
    offer_id          = simple.door.open
    intent_id         = open
    verb_id           = verb.open
    ability_id        = simple.ability.door.open
    priority          = 50
    default_candidate = true

Close reaction
    offer_id          = simple.door.close
    intent_id         = close
    verb_id           = verb.close
    ability_id        = simple.ability.door.close
    priority          = 50
    default_candidate = true
```

`ability_id` находится внутри target-local reaction. `GameInteractionOffer`, который увидит UI/AI, содержит semantic `offer_id/intent_id/verb_id`, но не раскрывает target-local ability implementation.

### Почему не нужен `_refresh_offers()`

Door abilities используют обычные owner requirements:

```text
simple.ability.door.open
    blocked_owner_tags = [state.open]

simple.ability.door.close
    required_owner_tags = [state.open]
```

`GameInteractionTarget.query_offers()` вызывает side-effect-free `GameAbilities.query_activation()` для reactions.

Следовательно:

```text
Door CLOSED
├── open  available
└── close unavailable

Door OPEN
├── open  unavailable
└── close available
```

Дверь не переписывает `offer_templates` вручную.

---

## 11.3. Обычный contextual interact

Кнопка `E` — обычный ability binding:

```text
E
→ GamePlayerInputSource
→ slot.interaction
→ simple.ability.player.interact
→ GameInteractionAbilityOperation
→ focused GameInteractionTarget
→ default currently available reaction
→ Door.GameAbilities
→ simple.ability.door.open / close
```

Если semantic intent пуст, target выбирает первый доступный `default_candidate` по priority.

Для закрытой двери это `open`, для открытой — `close`.

Ни в Player, ни в ControlEndpoint, ни в InteractionSource нет:

```gdscript
if target is GameDoorSimple:
    ...

if target.has_method("open_door"):
    ...
```

---

## 11.4. Направленное взаимодействие

AI, GOAP или cutscene часто знают желаемое состояние. Тогда активируется **та же** generic interaction ability, но с semantic intent:

```gdscript
request.set_activation_payload({
    GameInteractionRequest.ACTIVATION_INTENT_KEY: &"open",
})
```

При необходимости target передаётся обычным `GameAbilityActivationRequest.set_targets()`.

Mock AI может сделать то же через control source:

```gdscript
ai_control_source.use_ability(
    &"simple.ability.player.interact",
    [door_handle],
    execution_context,
    {GameInteractionRequest.ACTIVATION_INTENT_KEY: &"open"}
)
```

Семантика строгая:

```text
request(open) + CLOSED door  → door.open
request(open) + OPEN door    → rejection/unchanged от door.open requirements
request(open) + OPENING door → busy/rejection от door.open concurrency/requirements
```

`open` **никогда не превращается автоматически в `close`**.

---

## 11.5. Локальная реализация двери

Door-specific operation может знать конкретный game-specific root, потому что она является внутренней реализацией **door-owned ability**.

Например:

```gdscript
@tool
extends GameAbilityOperation
class_name GameDoorSetOpenOperationSimple

@export var open: bool = true

func execute(
    _abilities: GameAbilities,
    execution: GameAbilityExecution
) -> GameCommandResult:
    if execution == null or execution.get_request() == null:
        return GameCommandResult.configuration_error(
            &"door_execution_missing",
            "Door ability execution is incomplete."
        )

    var owner_handle: GameObjectHandle = execution.get_request().get_owner_handle()
    if owner_handle == null or not owner_handle.is_resolved():
        return GameCommandResult.invalid_target("Door ability owner is unresolved.")

    var door: GameDoorSimple = owner_handle.get_root() as GameDoorSimple
    if door == null:
        return GameCommandResult.invalid_target(
            "Door ability owner root does not provide GameDoorSimple state."
        )

    return door.set_open(open)
```

`GameDoorSimple.set_open()` может менять собственный `state.open`, Tween/Animation и сигналы. Это локальный API реализации двери, а не interaction protocol для внешних систем.

Полный цельный вариант приведён в [`example_simple_scene_complete_scripts.md`](./example_simple_scene_complete_scripts.md).

---

# 12. Бочка

Создайте:

```text
res://content/gameplay/simple_scene/barrel/prop_barrel_simple.tscn
```

## 12.1. Дерево

```text
Barrel (StaticBody3D)
├── Visual
├── CollisionShape3D
└── GameObjectKernel
    ├── GameObjectIdentity
    ├── GameTagContainer
    ├── GameAttributes
    ├── GameMeters
    ├── GameDamageReceiver
    ├── GameDeathPolicy
    └── GamePresentationCueReceiver
```

Если бочка тоже должна гореть до взрыва, добавьте `GameEffects` и scheduler для неё.

## 12.2. Здоровье

Для прототипа:

```text
MaxHealth = 40
Health    = 40 / 40
```

Tags:

```text
object.prop.barrel
```

Теперь атака игрока или explosion может выбирать бочку через capability `DAMAGE_RECEIVER`.

---

## 12.3. Получение урона

Урон идёт стандартно:

```text
Attack / Explosion
→ GameDamageRequest
→ Barrel.GameDamageReceiver
→ Health meter
→ depleted
→ GameDeathPolicy
→ barrel explode
```

Не встраивайте отдельную несовместимую систему `barrel_hp`.

---

## 12.4. Взрыв

В barrel script держите guard:

```gdscript
var _exploded: bool = false
```

В начале `explode()`:

```gdscript
if _exploded:
    return
_exploded = true
```

Устанавливайте guard **до** рассылки damage requests. Иначе две бочки могут рекурсивно взрывать друг друга несколько раз.

Далее:

1. создать `GameExecutionContext`;
2. получить собственный `GameObjectHandle`;
3. вызвать `targeting_service.query_sphere()`;
4. запросить цели с `GameCapabilityIds.DAMAGE_RECEIVER`;
5. исключить stable ID самой бочки;
6. каждой цели отправить `GameDamageRequest`;
7. tags урона: `damage.explosion`;
8. отправить presentation cue;
9. отключить collision;
10. удалить объект через короткую задержку.

Каркас target query:

```gdscript
var excluded_ids: Array[StringName] = [
    owner_handle.get_stable_id()
]

var query: Dictionary = targeting_service.query_sphere(
    global_position,
    explosion_radius,
    GameCapabilityIds.DAMAGE_RECEIVER,
    [],
    excluded_ids
)
```

Цепная реакция получится естественно:

```text
Barrel A explosion
→ DamageRequest в Barrel B
→ Barrel B health = 0
→ Barrel B DeathPolicy
→ Barrel B explosion
```

---

# 13. Мина

Создайте:

```text
res://content/gameplay/simple_scene/mine/prop_mine_simple.tscn
```

## 13.1. Дерево

```text
Mine (Area3D)
├── Visual
├── BodyCollision (CollisionShape3D)
├── TriggerCollision (CollisionShape3D)
│
└── GameObjectKernel
    ├── GameObjectIdentity
    ├── GameTagContainer
    ├── GameAttributes
    ├── GameMeters
    ├── GameEffects               # если нужно принимать эффекты
    ├── GameDamageReceiver
    ├── GameDeathPolicy
    └── GamePresentationCueReceiver
```

Экспортируемые зависимости игрового скрипта:

```gdscript
@export var kernel: GameObjectKernel = null
@export var targeting_service: GameTargetingService = null
@export var trigger_collision: CollisionShape3D = null
```

Runtime-зависимости, задаваемые при spawn:

```text
owner_handle
instigator_handle
object_resolver
targeting_service
```

---

## 13.2. Установка мины

Цикл:

```text
Player presses Q
→ GameAbilities.activate(simple.ability.player.place_mine)
→ operation/request spawn
→ MainScene instantiate Mine
→ inject world services + owner handle
→ register mine handle
→ wait arming delay
→ arm
```

Не делайте мину вооружённой прямо в момент spawn рядом с collider игрока.

---

## 13.3. Armed state

Пример состояний:

```text
PLACED
ARMED
EXPLODED
```

На spawn:

```text
armed = false
TriggerCollision.disabled = true
```

Через 0.35 секунды:

```text
armed = true
TriggerCollision.disabled = false
```

Для production лучше переключать physics collision безопасным способом, учитывая правила Godot для изменения collision state во время physics callback.

---

## 13.4. Реагирование на body_entered

Не выбрасывайте аргумент `body`.

Плохой вариант:

```gdscript
func _on_body_entered(_body: Node3D) -> void:
    trigger()
```

В таком коде теряется информация о том, **кто** наступил на мину.

Нужная схема:

```text
body
→ найти/получить его GameObjectKernel/Context
→ получить GameObjectHandle
→ проверить owner/faction/rules
→ trigger(instigator_handle)
```

Перед детонацией проверьте:

```text
armed == true
exploded == false
body — GCA объект
handle resolved
handle != owner_handle
цель удовлетворяет правилам мины
```

Collision mask мины должен видеть Player/Monster layers, которые действительно должны её активировать.

---

## 13.5. Мина получает урон

Для мины создайте:

```text
MaxHealth = 20
Health    = 20 / 20
```

Наличие `GameDamageReceiver` позволяет:

```text
Player attack
→ Mine DamageReceiver
→ Mine Health 20 → 0
→ DeathPolicy
→ explode()
```

Таким образом мина может взрываться двумя путями:

```text
Trigger entered
        ┐
        ├→ explode_once()
Health depleted
        ┘
```

Оба пути должны сходиться в **один** метод с guard `_exploded`.

---

## 13.6. Взрыв мины

Рекомендуемые параметры:

```text
explosion_radius = 3.0
explosion_damage = 50.0
```

В начале:

```gdscript
if _exploded:
    return
_exploded = true
_armed = false
```

Сразу отключите trigger, чтобы новые `body_entered` не создавали повторные события.

Далее query:

```gdscript
var query: Dictionary = targeting_service.query_sphere(
    global_position,
    explosion_radius,
    GameCapabilityIds.DAMAGE_RECEIVER,
    [],
    excluded_ids
)
```

На каждую цель:

```gdscript
var damage_tags: Array[StringName] = [
    &"damage.explosion"
]

var request := GameDamageRequest.new(
    mine_handle,
    instigator_handle,
    target_handle,
    explosion_damage,
    damage_tags,
    execution_context
)

receiver.apply_damage(request)
```

### Что важно проверить

Если мина визуально «взорвалась», но никто не получил урон, проверяйте по порядку:

1. `targeting_service != null`;
2. mine kernel имеет context;
3. цели зарегистрированы/разрешаются world services;
4. у целей есть `GameDamageReceiver`;
5. query использует правильный capability ID;
6. collision/physics world находится в корректном состоянии;
7. вы не исключили нужную цель через stable ID/tags;
8. damage request действительно дошёл до receiver.

---

# 14. Мина накладывает статус «Горение»

Explosion damage и Burning — это **две разные операции**.

Схема:

```text
Mine explosion
├── immediate GameDamageRequest: 50 explosion
└── apply GameEffect: simple.effect.burning
                         ↓
                    status.burning
                         ↓
                 periodic fire damage
```

## 14.1. Кто может получить Burning

На цели должен существовать `GameEffects` capability/runtime-компонент.

Для этого прототипа `GameEffects` нужен как минимум у:

- Player;
- Monster.

Если хотите поджигать бочки — добавьте его и бочкам.

## 14.2. Наложение effect

После успешного explosion hit получите target context и capability effects, затем примените `simple.effect.burning` через публичный API `GameEffects`, сохранив тот же/root-child `GameExecutionContext` согласно используемой operation.

Не храните отдельный bool:

```gdscript
is_burning = true
```

если состояние уже моделируется GCA effect + tag.

## 14.3. Периодический урон

Каждый tick Burning должен создавать:

```text
GameDamageRequest
amount = 5
tag    = damage.fire
source/instigator = источник эффекта
```

Это важно, потому что тогда:

- смерть от огня проходит через тот же DeathPolicy;
- resistances/immunity можно добавить централизованно;
- combat log знает источник;
- friendly-fire rules остаются согласованными.

## 14.4. Scheduler обязателен

У получателя эффекта должен выполняться:

```gdscript
effects.advance_time(delta, execution_context)
```

Локальное продвижение времени owner/subscene является допустимой и намеренной моделью. Не обязательно выносить все entities в один глобальный scheduler.

---

# 15. Общий helper для radial damage

Бочку и мину удобно свести к одному стилю кода.

Каркас алгоритма:

```gdscript
func apply_radial_damage(
    source_handle: GameObjectHandle,
    instigator_handle: GameObjectHandle,
    center: Vector3,
    radius: float,
    damage: float,
    damage_tags: Array[StringName],
    execution_context: GameExecutionContext
) -> int:
    var excluded_ids: Array[StringName] = [
        source_handle.get_stable_id()
    ]

    var query: Dictionary = targeting_service.query_sphere(
        center,
        radius,
        GameCapabilityIds.DAMAGE_RECEIVER,
        [],
        excluded_ids
    )

    var affected_count: int = 0

    for handle_value: Variant in query.get("handles", []):
        var target_handle: GameObjectHandle = handle_value as GameObjectHandle
        if target_handle == null or not target_handle.is_resolved():
            continue

        var target_context: GameObjectContext = target_handle.get_context()
        if target_context == null:
            continue

        var receiver: GameDamageReceiver = target_context.get_capability(
            GameCapabilityIds.DAMAGE_RECEIVER
        ) as GameDamageReceiver

        if receiver == null:
            continue

        var request := GameDamageRequest.new(
            source_handle,
            instigator_handle,
            target_handle,
            damage,
            damage_tags,
            execution_context
        )

        if receiver.apply_damage(request).is_success():
            affected_count += 1

    return affected_count
```

Это каркас для обучения. В production вынесите общую combat-запросную логику в подходящий сервис/operation, чтобы Mine и Barrel не дублировали её.

---

# 16. Что ещё нужно для полноценного прототипа

В исходном списке были основные gameplay-объекты, но для реально работающей сцены нужны ещё несколько частей.

## 16.1. World resolver и targeting service

Без них динамические объекты и radial abilities легко превращаются в «визуально работают, но никого не находят».

## 16.2. Регистрация динамических объектов

Каждая созданная runtime mine должна войти в тот же world lifecycle, что и объекты, уже лежавшие в `.tscn`.

## 16.3. Faction/friendly fire

Заранее определите:

```text
Player attacks Monster
Monster attacks Player
Mine owner ignored?
Mine damages other player?
Explosion damages barrels?
Explosion damages placer?
```

Не размазывайте эти решения по пяти scripts.

## 16.4. Navigation

Монстр без navmesh и `NavigationAgent3D` сможет знать, куда идти, но не сможет корректно обходить стены.

## 16.5. Interaction focus и semantic reactions

Generic interaction ability должна получить target одним из двух путей:

```text
explicit ability target handle
```

или:

```text
current GameInteractionSource focus
```

Механизм world/camera/proximity focus остаётся отдельной targeting integration. После получения target никакого command dispatcher не нужен:

```text
GameInteractionRequest
→ GameInteractionTarget
→ GameInteractionReaction
→ target-local GameAbilities
```

## 16.6. Scheduler

Периодические effects, duration и ability cooldown должны получать time advancement. В этом прототипе scheduler остаётся локальным у owner/subscene.

## 16.7. Death state

После смерти объект должен перестать принимать решения/управление, а не продолжать ходить с `Health == 0`.

## 16.8. Presentation

Gameplay logic не должна зависеть от конкретного VFX.

Правильнее:

```text
mine exploded
→ gameplay state уже изменён
→ presentation cue / signal
→ VFX/SFX слой показывает взрыв
```

## 16.9. HUD/debug

Для учебной сцены очень полезно вывести:

```text
Player HP
Monster HP
Monster AI State
Player current control owner
Interaction focused target
Interaction current offers/intents
Mine armed state
Mine last affected_count
Burning active / remaining time
```

Так вы сразу видите, где нарушился pipeline.

## 16.10. Restart

Добавьте простой restart сцены после смерти игрока. Это ускоряет тестирование полного цикла.

---

# 17. Рекомендуемый порядок разработки

Не пытайтесь собрать всё одновременно.

## Шаг 1 — World

Сделайте:

- физический floor;
- world services;
- navigation;
- пустые spawn/patrol containers.

Проверка: сцена запускается без ошибок.

## Шаг 2 — Player movement

Добавьте:

- Kernel;
- Identity;
- Tags;
- Attributes;
- Control;
- Motor;
- PlayerInputSource.

Проверка: WASD двигает игрока.

## Шаг 3 — Player health

Добавьте:

- Health meter;
- DamageReceiver;
- DeathPolicy.

Временно отправьте тестовый `GameDamageRequest`.

Проверка:

```text
100 → 75
```

## Шаг 4 — Player attack

Добавьте ability и test dummy/monster.

Проверка: Mouse1 уменьшает HP цели через `GameDamageReceiver`.

## Шаг 5 — Monster

Сначала только:

- health;
- AI control;
- patrol.

Потом добавьте chase.

Потом attack.

## Шаг 6 — Dodge

Добавьте temporary control override.

Проверка №1: рывок работает.

Проверка №2: после рывка WASD снова работает.

Только после этого добавляйте i-frames.

## Шаг 7 — Door interaction

Сначала:

1. создайте `door.open` / `door.close` abilities;
2. добавьте `state.open` requirements;
3. настройте `GameInteractionReaction`;
4. убедитесь, что closed door query показывает только `open`;
5. свяжите `E → slot.interaction → generic interact ability`;
6. проверьте default interact;
7. отдельно проверьте `intent.open` на уже открытой двери — он не должен вызвать close;
8. только затем добавляйте полноценную анимацию/presentation.

## Шаг 8 — Barrel

Сначала damage/death.

Потом explosion.

Потом две бочки и chain reaction.

## Шаг 9 — Place Mine

Сначала ability создаёт mine scene.

Потом world injection/registration.

Потом arming delay.

## Шаг 10 — Mine explosion

Проверьте:

- monster входит в Area;
- mine получает правильный instigator;
- `affected_count > 0`;
- Monster Health уменьшается.

## Шаг 11 — Mine damageability

Атакуйте мину игроком.

Проверка:

```text
Mine Health → 0
→ explosion exactly once
```

## Шаг 12 — Burning

Добавьте effect последним.

Проверка:

```text
Explosion immediate damage
→ status.burning appears
→ fire damage every period
→ effect expires
```

---

# 18. Полный ожидаемый игровой цикл

После завершения сцена должна работать так.

## Игрок

```text
WASD
→ PlayerInputSource
→ ControlArbiter
→ ControlEndpoint
→ CharacterMotor
→ movement
```

```text
Mouse1
→ slot.primary
→ GameAbilities
→ Player Attack Operation
→ TargetingService
→ Monster/Barrel/Mine DamageReceiver
→ Health
```

```text
Space
→ Dodge Ability
→ temporary movement ownership
→ dash
→ release ownership
→ normal player movement restored
```

```text
Q
→ PlaceMine Ability
→ spawn request
→ MainScene creates mine
→ inject services
→ register handle
→ arm
```

## Монстр

```text
PATROL
→ sees player
→ CHASE
→ reaches attack distance
→ ATTACK
→ GameAbilities
→ GameDamageRequest
→ Player DamageReceiver
```

## Дверь

```text
E
→ slot.interaction
→ generic interaction ability
→ GameInteractionAbilityOperation
→ GameInteractionTarget
→ available semantic reaction
→ Door.GameAbilities
→ door.open / door.close
```

Направленный AI вариант:

```text
GOAP wants OPEN
→ generic interaction ability(target=door, intent=open)
→ Door reaction(open)
→ door.open only
```

## Бочка

```text
DamageRequest
→ Health = 0
→ DeathPolicy
→ explosion
→ TargetingService
→ radial DamageRequests
→ possible chain reaction
```

## Мина

```text
PlaceMine Ability
→ spawn
→ arm
→ monster enters Area
→ resolve instigator
→ explosion
├→ explosion damage
└→ Burning effect
```

---

# 19. Частые ошибки и диагностика

## Мина лежит и ничего не делает

Проверьте:

- назначен ли `GameTargetingService`;
- включён ли monitoring Area3D;
- совпадают ли collision layers/masks;
- вооружена ли мина;
- есть ли у цели `GameDamageReceiver`;
- не равен ли target owner handle;
- зарегистрированы ли handles;
- возвращает ли query хотя бы один handle.

## Мина срабатывает, но HP не меняется

Проверьте:

- `affected_count`;
- capability `DAMAGE_RECEIVER`;
- правильный health meter ID;
- результат `receiver.apply_damage(request)`;
- правила иммунитета/faction.

## Ability возвращает success, но ничего визуально не происходит

`GameCommandResult.success` означает, что команда была принята/выполнена согласно operation, а не гарантирует наличие VFX.

Отдельно проверяйте gameplay result и presentation.

## Монстр стоит на месте

Проверьте:

- navmesh запечён;
- `NavigationAgent3D` имеет путь;
- player target назначен;
- AI source `attach()` успешен;
- AI source получил control;
- monster не находится внутри stop/attack distance;
- движение не перезаписывается вторым скриптом.

## Door не реагирует на E

Проверьте по цепочке:

1. `interact` привязан к `slot.interaction`;
2. slot резолвится в grant generic interaction ability;
3. у generic ability есть `GameInteractionAbilityOperation`;
4. у `GameInteractionSource` есть focus или ability request содержит explicit target;
5. у Door есть `GameInteractionTarget` и local `GameAbilities`;
6. reactions валидны;
7. `door.open/close` grants существуют;
8. `state.open` зарегистрирован в tag catalog;
9. `query_activation()` действительно считает нужную door ability доступной.

Не добавляйте `if target is Door` или `has_method()` для исправления этой цепочки.

## `intent.open` неожиданно закрывает дверь

Это нарушение semantic interaction contract. Explicit intent должен фильтровать только reactions с `intent_id == open`. Он не должен fallback-иться на default `close`.

## Burning появился, но не наносит периодический урон

Проверьте:

- есть ли `GameEffects` у цели;
- вызывается ли `effects.advance_time()`;
- существует ли periodic operation;
- operation создаёт ли `GameDamageRequest`;
- не отклоняется ли `damage.fire` damage policy.

## После Dodge игрок больше не двигается

Временный владелец movement channel не освободил control.

## Бочка/мина взрывается несколько раз

Guard `_exploded` выставлен слишком поздно. Установите его в самом начале `explode()` до нанесения radial damage.

## У объекта есть Health, но targeting его не находит

Health meter и `GameDamageReceiver` — не одно и то же. Query по `GameCapabilityIds.DAMAGE_RECEIVER` требует соответствующий capability.

---

# 20. Checklist готового прототипа

Перед тем как считать сцену рабочей, пройдите весь список.

- [ ] Main Scene запускается без ошибок.
- [ ] Floor имеет физическую collision shape.
- [ ] `GameObjectResolver` доступен объектам мира.
- [ ] `GameTargetingService` передан объектам, которым нужен targeting.
- [ ] Player зарегистрирован как GCA object.
- [ ] Monster зарегистрирован как GCA object.
- [ ] Door зарегистрирован как GCA object, если используется world resolver/focus.
- [ ] Barrels зарегистрированы как GCA objects.
- [ ] Динамические mines регистрируются после spawn.
- [ ] Player двигается через control pipeline.
- [ ] Player Health начинается с полного значения.
- [ ] Player имеет `GameDamageReceiver`.
- [ ] Player attack наносит урон Monster.
- [ ] Dodge временно перехватывает movement и затем возвращает его.
- [ ] Place Mine создаёт мину в `SpawnedMines`.
- [ ] Mine получает owner/instigator handle.
- [ ] Mine получает world targeting service.
- [ ] Mine не взрывается мгновенно от собственного владельца.
- [ ] Monster патрулирует заданные точки.
- [ ] Monster начинает chase после обнаружения Player.
- [ ] Monster останавливается на attack distance.
- [ ] Monster attack наносит Player damage через `GameDamageRequest`.
- [ ] Dead Monster больше не двигается и не атакует.
- [ ] Player `interact` идёт через ability slot, а не отдельный door method.
- [ ] Door имеет local `GameAbilities`.
- [ ] Door reaction `open` ссылается на `door.open` ability.
- [ ] Door reaction `close` ссылается на `door.close` ability.
- [ ] Closed Door query выдаёт semantic `open` offer.
- [ ] Open Door query выдаёт semantic `close` offer.
- [ ] Default interact открывает закрытую и закрывает открытую дверь.
- [ ] Explicit `intent.open` на открытой двери не вызывает `close`.
- [ ] Interaction code не проверяет target class и не использует `has_method("activate")`.
- [ ] Barrel получает урон.
- [ ] Barrel взрывается только один раз.
- [ ] Две бочки могут дать контролируемую chain reaction.
- [ ] Mine может получить урон и взорваться от depletion.
- [ ] Monster может активировать Mine через trigger.
- [ ] Explosion уменьшает Health целей.
- [ ] Explosion накладывает `simple.effect.burning` на поддерживаемые цели.
- [ ] Burning создаёт периодический `damage.fire`.
- [ ] Burning завершается по duration.
- [ ] `abilities.advance_time()` вызывается для runtime abilities.
- [ ] `effects.advance_time()` вызывается для runtime effects.
- [ ] `kernel.process_execution_queue()` вызывается там, где требуется runtime execution queue.
- [ ] Gameplay code не использует прямые цепочки `get_parent().some_gameplay_method()`.
- [ ] Дочерние компоненты сообщают наверх через signals, а родитель явно управляет дочерними зависимостями.

---

# 21. Главное правило работы с API GCA

Когда появляется новая gameplay-механика, задавайте вопросы в таком порядке:

```text
1. Кто является GameObject?
2. Какие capability ему нужны?
3. Какие data definitions можно создать через GCA Data Studio?
4. Кто принимает решение/ввод?
5. Какая Ability выражает намерение инициатора?
6. Как выбирается Target?
7. Какой semantic Request/Reaction определяет ответ цели?
8. Какая target-owned Ability реально меняет состояние цели?
9. Как Meter/Tags/DeathPolicy отражают результат?
10. Как Presentation показывает результат игроку?
11. Кто владеет lifecycle, scheduler и world registration?
```

На примере двери:

```text
Player / AI
→ generic Interact Ability
→ GameInteractionRequest(default или intent.open)
→ Door.GameInteractionTarget
→ GameInteractionReaction
→ Door.GameAbilities
→ door.open / door.close
→ state.open / presentation
```

На примере мины:

```text
Player
→ PlaceMine Ability
→ World spawns Mine GameObject
→ Mine arms
→ Monster enters trigger
→ Mine resolves Monster Handle
→ TargetingService finds damageable objects
→ GameDamageRequest
→ GameDamageReceiver
→ Health Meter
→ Burning GameEffect
→ DeathPolicy if depleted
→ Presentation cue
```

Если каждый этап этой цепочки можно отдельно проверить, архитектура остаётся модульной, а ошибка вроде «мина просто лежит» или «дверь не открывается» быстро локализуется до конкретного отсутствующего звена.
