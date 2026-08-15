# Пример: выносим общий combat-код из Mine и Barrel

Этот документ раскрывает фразу из `docs/example_simple_scene.md`:

> «В production вынесите общую combat-запросную логику в подходящий сервис/operation, чтобы Mine и Barrel не дублировали её».

Цель примера — показать **что именно выносить, куда, зачем и как потом этим пользоваться**.

> Важно: `GameCombatService` ниже — это **не класс ядра GCA**. Это project-level сервис нашей игры, построенный поверх публичного API GCA: `GameTargetingService`, `GameDamageRequest`, `GameDamageReceiver`, `GameObjectHandle`, `GameObjectContext`.

---

# 1. Какая проблема решается

Без общего сервиса `Mine` и `Barrel` начинают содержать почти одинаковый код.

Например, и мина, и бочка делают одно и то же:

```text
1. Найти все damageable-цели в радиусе.
2. Исключить сам источник взрыва.
3. Получить GameObjectContext каждой цели.
4. Получить GameDamageReceiver.
5. Создать GameDamageRequest.
6. Вызвать receiver.apply_damage(request).
7. Посчитать, сколько целей реально приняли урон.
```

Если этот алгоритм написать отдельно в `game_mine_simple.gd` и отдельно в `game_barrel_simple.gd`, появляется дублирование.

Через некоторое время может получиться так:

```text
Mine explosion
- исключает source
- правильно передаёт instigator
- проверяет is_resolved()
- считает successful hits

Barrel explosion
- забывает исключить source
- передаёт неправильный instigator
- не проверяет is_resolved()
- игнорирует GameCommandResult
```

Обе механики вроде бы «взрыв», но начинают работать по-разному.

Поэтому повторяемую техническую часть лучше собрать в одном месте.

---

# 2. Что остаётся в Mine и Barrel

Очень важно не вынести в сервис вообще всё.

`Mine` всё ещё должна знать:

```text
- вооружена ли она;
- кто наступил на trigger;
- когда ей взрываться;
- какой radius у конкретной мины;
- какой damage у конкретной мины;
- нужно ли после взрыва наложить Burning;
- когда отключить trigger;
- когда показать VFX;
- когда удалить себя.
```

`Barrel` всё ещё должна знать:

```text
- взорвалась ли она уже;
- что Health дошёл до 0;
- какой radius у этой бочки;
- какой damage у этой бочки;
- когда отключить collision;
- когда показать VFX;
- когда удалить себя.
```

А общий сервис знает только повторяемую combat-механику:

```text
"Вот источник, инициатор, центр, радиус и урон.
 Найди подходящие GCA-цели и отправь им GameDamageRequest."
```

Это и есть граница ответственности.

---

# 3. Рекомендуемая структура

Добавьте общий игровой модуль:

```text
res://content/gameplay/common/combat/
└── game_combat_service.gd
```

Основная сцена:

```text
SimpleScene
├── WorldServices
│   ├── GameObjectResolver
│   ├── GameTargetingService
│   └── GameCombatService
│
├── Player
├── Monster
├── Barrels
└── SpawnedMines
```

`GameCombatService` является world-level зависимостью.

Он не должен искать `GameTargetingService` через:

```gdscript
get_parent().find_child(...)
```

Основная сцена явно связывает зависимости.

---

# 4. Сам GameCombatService

Создайте:

```text
res://content/gameplay/common/combat/game_combat_service.gd
```

Пример:

```gdscript
class_name GameCombatService
extends Node


# -----------------------------------------------------------------------------
# Dependencies
# -----------------------------------------------------------------------------

@export var targeting_service: GameTargetingService = null


# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------

func apply_damage(
    source_handle: GameObjectHandle,
    instigator_handle: GameObjectHandle,
    target_handle: GameObjectHandle,
    damage: float,
    damage_tags: Array[StringName],
    execution_context: GameExecutionContext
) -> bool:
    if target_handle == null:
        return false

    if not target_handle.is_resolved():
        return false

    var target_context: GameObjectContext = target_handle.get_context()
    if target_context == null:
        return false

    var receiver: GameDamageReceiver = target_context.get_capability(
        GameCapabilityIds.DAMAGE_RECEIVER
    ) as GameDamageReceiver

    if receiver == null:
        return false

    var request := GameDamageRequest.new(
        source_handle,
        instigator_handle,
        target_handle,
        damage,
        damage_tags,
        execution_context
    )

    return receiver.apply_damage(request).is_success()


func apply_radial_damage(
    source_handle: GameObjectHandle,
    instigator_handle: GameObjectHandle,
    center: Vector3,
    radius: float,
    damage: float,
    damage_tags: Array[StringName],
    execution_context: GameExecutionContext,
    additional_excluded_ids: Array[StringName] = []
) -> int:
    if targeting_service == null:
        return 0

    if source_handle == null:
        return 0

    var excluded_ids: Array[StringName] = []

    for stable_id: StringName in additional_excluded_ids:
        excluded_ids.append(stable_id)

    var source_stable_id: StringName = source_handle.get_stable_id()
    if not excluded_ids.has(source_stable_id):
        excluded_ids.append(source_stable_id)

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

        if apply_damage(
            source_handle,
            instigator_handle,
            target_handle,
            damage,
            damage_tags,
            execution_context
        ):
            affected_count += 1

    return affected_count
```

Обратите внимание: `apply_radial_damage()` **не создаёт `GameDamageRequest` самостоятельно**.

Он делегирует это второму общему методу:

```gdscript
apply_damage(...)
```

Поэтому у нас уже два уровня повторного использования:

```text
apply_damage()
    ↓
одна цель

apply_radial_damage()
    ↓
поиск множества целей
    ↓
для каждой цели вызывает apply_damage()
```

---

# 5. Что теперь исчезает из Mine

Раньше внутри `Mine.explode()` пришлось бы писать примерно такой код:

```text
query_sphere()
→ цикл handles
→ get_context()
→ get_capability(DAMAGE_RECEIVER)
→ GameDamageRequest.new(...)
→ receiver.apply_damage(...)
```

Теперь `Mine` не обязана знать детали доставки damage request каждой цели.

Она говорит сервису только:

```text
"Я взорвалась здесь.
 Мой radius = 3.
 Мой damage = 50.
 Источник — эта мина.
 Инициатор — игрок, который её установил."
```

---

# 6. Mine после рефакторинга

В `game_mine_simple.gd` добавьте зависимость:

```gdscript
var _combat_service: GameCombatService = null
```

И метод явного внедрения зависимости:

```gdscript
func set_combat_service(value: GameCombatService) -> void:
    _combat_service = value
```

Не ищите сервис через родителей.

Взрыв становится намного короче:

```gdscript
func explode() -> void:
    if _exploded:
        return

    _exploded = true
    _armed = false

    if trigger_collision != null:
        trigger_collision.set_deferred("disabled", true)

    if _combat_service == null:
        return

    if kernel == null:
        return

    var object_context: GameObjectContext = kernel.get_object_context()
    if object_context == null:
        return

    var mine_handle: GameObjectHandle = object_context.get_object_handle()

    var execution_context: GameExecutionContext = (
        object_context.create_root_execution_context(
            &"simple.mine.explosion",
            "Mine explosion"
        )
    )

    var damage_tags: Array[StringName] = [
        &"damage.explosion"
    ]

    var excluded_ids: Array[StringName] = []

    if _owner_handle != null:
        excluded_ids.append(_owner_handle.get_stable_id())

    var affected_count: int = _combat_service.apply_radial_damage(
        mine_handle,
        _instigator_handle,
        global_position,
        explosion_radius,
        explosion_damage,
        damage_tags,
        execution_context,
        excluded_ids
    )

    mine_exploded.emit(affected_count)
```

Теперь Mine отвечает за **решение взорваться и параметры взрыва**, а не за внутренний protocol нанесения урона каждой цели.

Схема стала такой:

```text
Mine
→ "нужно сделать explosion damage"
→ GameCombatService.apply_radial_damage()
→ GameTargetingService.query_sphere()
→ GameCombatService.apply_damage()
→ GameDamageRequest
→ target GameDamageReceiver
```

---

# 7. Barrel после рефакторинга

Бочке передаётся тот же сервис:

```gdscript
var _combat_service: GameCombatService = null


func set_combat_service(value: GameCombatService) -> void:
    _combat_service = value
```

Взрыв:

```gdscript
func explode() -> void:
    if _exploded:
        return

    _exploded = true

    if _combat_service == null:
        return

    if kernel == null:
        return

    var object_context: GameObjectContext = kernel.get_object_context()
    if object_context == null:
        return

    var barrel_handle: GameObjectHandle = object_context.get_object_handle()

    var execution_context: GameExecutionContext = (
        object_context.create_root_execution_context(
            &"simple.barrel.explosion",
            "Barrel explosion"
        )
    )

    var damage_tags: Array[StringName] = [
        &"damage.explosion"
    ]

    var affected_count: int = _combat_service.apply_radial_damage(
        barrel_handle,
        barrel_handle,
        global_position,
        explosion_radius,
        explosion_damage,
        damage_tags,
        execution_context
    )

    barrel_exploded.emit(affected_count)
```

Обратите внимание на различие source/instigator.

Для бочки в самом простом примере используется:

```text
source     = Barrel
instigator = Barrel
```

Для мины:

```text
source     = Mine
instigator = Player, который поставил Mine
```

Это полезно для дальнейших систем:

```text
- combat log;
- aggro;
- XP/kill credit;
- quests;
- friendly fire;
- achievements;
- AI reaction.
```

Если бочка была взорвана игроком и вы хотите сохранить цепочку причин, можно отдельно решить, должен ли её explosion наследовать исходного instigator. Это уже правило вашей игры, а не обязанность `GameCombatService`.

---

# 8. Как Main Scene передаёт сервис

Главная сцена владеет world services и знает свои дочерние объекты.

Пример:

```gdscript
@export var combat_service: GameCombatService = null
@export var barrel_01: Node = null
@export var barrel_02: Node = null


func _ready() -> void:
    if barrel_01 != null:
        barrel_01.set_combat_service(combat_service)

    if barrel_02 != null:
        barrel_02.set_combat_service(combat_service)
```

Для динамической мины:

```gdscript
func spawn_mine(...) -> void:
    var mine: Node = mine_scene.instantiate()

    spawned_mines.add_child(mine)

    mine.set_combat_service(combat_service)
    mine.set_owner_handle(player_handle)
    mine.set_instigator_handle(player_handle)
```

Главный принцип иерархии остаётся прежним:

```text
родитель знает детей
→ родитель передаёт зависимость ребёнку

ребёнок
→ не ищет gameplay services через get_parent().get_parent()...
```

---

# 9. Почему нельзя просто сделать static utility

Технически можно написать:

```gdscript
GameCombatUtility.apply_radial_damage(...)
```

Но radial damage требует `GameTargetingService` конкретного мира.

Если static utility начнёт самостоятельно искать singleton/autoload/world, зависимость станет скрытой.

В данном случае world-level service удобнее:

```text
GameCombatService
└── явная зависимость GameTargetingService
```

И затем:

```text
MainScene
→ явно передаёт GameCombatService
→ Mine / Barrel / Ability Operation
```

Static helper имеет смысл для **чистых функций**, которым не нужен runtime world state.

Например:

```text
calculate_falloff(distance, radius)
calculate_critical_multiplier(...)
normalize_damage_tags(...)
```

Но поиск GCA-объектов мира лучше оставить сервису, которому world dependency передана явно.

---

# 10. А где здесь Ability Operation

Фраза «сервис/operation» не означает, что нужно выбрать только что-то одно.

У них разные роли.

## Operation отвечает за конкретное игровое действие

Например:

```text
PlayerAttackOperation
FireballImpactOperation
MonsterAttackOperation
```

Operation знает смысл конкретной способности:

```text
- какой damage;
- какой radius;
- какие tags;
- какую цель брать;
- какой cooldown/ability context привёл к действию.
```

Но сама operation может использовать общий сервис:

```text
PlayerAttackOperation
→ GameCombatService.apply_damage()
```

или:

```text
FireballImpactOperation
→ GameCombatService.apply_radial_damage()
```

## Service отвечает за повторяемую механику доставки запроса

```text
GameCombatService
→ resolve target context
→ find DamageReceiver
→ construct GameDamageRequest
→ call apply_damage()
```

Таким образом:

```text
Ability Operation = "ЧТО сейчас делает gameplay?"
GameCombatService  = "КАК стандартно отправить combat request?"
GameDamageReceiver = "КАК цель принимает этот request?"
```

Это три разные ответственности.

---

# 11. Пример: Player Attack тоже начинает использовать сервис

До сервиса attack operation могла сама повторять:

```text
get target context
→ get DAMAGE_RECEIVER
→ GameDamageRequest.new
→ receiver.apply_damage
```

После появления сервиса:

```gdscript
var damage_tags: Array[StringName] = [
    &"damage.melee"
]

var success: bool = combat_service.apply_damage(
    actor_handle,
    actor_handle,
    target_handle,
    attack_damage,
    damage_tags,
    execution_context
)
```

Теперь Mine, Barrel и Attack используют один и тот же нижний уровень:

```text
                     ┌→ Player Attack Operation
                     │
GameCombatService ←──┼→ Mine
                     │
                     └→ Barrel
```

И все три пути в итоге создают стандартный:

```text
GameDamageRequest
→ GameDamageReceiver
```

---

# 12. Что НЕ надо помещать в GameCombatService

Не превращайте сервис в огромный «CombatManager», который знает всю игру.

Не надо переносить туда:

```text
- Mine arming delay;
- Barrel explode animation;
- Player attack animation;
- Monster AI;
- Health UI;
- door interaction;
- удаление corpse;
- конкретные VFX конкретной способности.
```

И особенно не надо делать внутри сервиса:

```gdscript
# Не надо
monster.health -= damage
```

Сервис должен продолжать пользоваться GCA:

```text
GameDamageRequest
→ GameDamageReceiver
```

Он не заменяет GCA damage pipeline.

Он лишь убирает повторяющийся код **использования** этого pipeline.

---

# 13. Куда помещать friendly fire и immunity

Не спешите помещать все правила в `GameCombatService`.

Например:

```text
status.invulnerable
fire resistance
armor
damage immunity
```

обычно относятся к правилам **приёма** урона целью и должны оставаться ближе к `GameDamageReceiver`/damage policy.

А правило:

```text
"мина владельца вообще не должна выбирать владельца как цель"
```

может быть выражено раньше — через `excluded_ids` при radial query.

То есть есть два разных вопроса:

```text
Targeting:
"Кого вообще попробовать задеть?"

Damage receiving/policy:
"Что произойдёт, когда запрос уже пришёл?"
```

Не смешивайте их.

---

# 14. Почему этот вариант удобнее расширять

Представим, что через месяц вы хотите добавить falloff у взрыва.

Сейчас:

```text
в центре = 100% damage
на краю = 25% damage
```

Без сервиса придётся менять:

```text
Mine
Barrel
Rocket
Grenade
Fireball
ExplodingCrate
...
```

С общим сервисом можно добавить отдельный radial API или policy в одном месте.

Например:

```text
apply_radial_damage_with_falloff(...)
```

И затем постепенно перевести вызывающие механики на него.

То же касается:

```text
- единой диагностики;
- combat logging;
- telemetry;
- debug draw радиуса;
- hit counters;
- централизованной проверки корректности handles.
```

---

# 15. Минимальный порядок внедрения

Не переписывайте всё сразу.

## Шаг 1

Создайте `GameCombatService` только с:

```gdscript
apply_damage(...)
```

Переведите на него обычную атаку игрока.

Проверка:

```text
Player Attack
→ GameCombatService
→ GameDamageRequest
→ Monster DamageReceiver
→ HP уменьшается
```

## Шаг 2

Добавьте:

```gdscript
apply_radial_damage(...)
```

Переведите бочку.

Проверка:

```text
Barrel explosion
→ nearby Monster loses HP
→ nearby Barrel receives damage
```

## Шаг 3

Переведите мину.

Проверка:

```text
Mine explosion
→ owner excluded
→ Monster receives explosion damage
```

## Шаг 4

Только затем добавляйте Burning поверх уже работающего explosion damage.

---

# 16. Самая важная мысль

До рефакторинга:

```text
Mine
├── знает query_sphere
├── знает DamageReceiver lookup
├── знает GameDamageRequest construction
└── знает apply_damage

Barrel
├── знает query_sphere
├── знает DamageReceiver lookup
├── знает GameDamageRequest construction
└── знает apply_damage
```

После рефакторинга:

```text
Mine
└── "взорваться: radius 3, damage 50"
        ↓

Barrel
└── "взорваться: radius 4, damage 80"
        ↓

GameCombatService
├── query_sphere
├── resolve target capability
├── GameDamageRequest
└── GameDamageReceiver.apply_damage
```

То есть мы **не прячем gameplay**, а убираем повторение технического protocol-кода.

Если вы забудете, что означала исходная фраза, запомните короткое правило:

> **Mine решает, КОГДА и С КАКИМИ параметрами взорваться. GameCombatService знает, КАК стандартно доставить этот урон GCA-целям.**
