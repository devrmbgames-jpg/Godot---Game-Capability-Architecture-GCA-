# Цельные скрипты-шаблоны к `example_simple_scene.md`

Этот документ дополняет [`example_simple_scene.md`](./example_simple_scene.md) цельными GDScript-файлами, которые удобнее переносить в проект целиком.

Основной tutorial остаётся главным источником для:

- дерева сцен;
- создания `.tres` через GCA Data Studio;
- Inspector wiring;
- collision layers/masks;
- navigation;
- faction/friendly-fire правил;
- presentation;
- настройки `GameDeathPolicy`;
- Burning effect.

Здесь собран именно **game-specific glue-код**.

> Важно: GCA не обязан знать, что такое «бочка», «мина», «дверь» или «рывок игрока». Скрипты игрового уровня используют публичные GCA-контракты. В частности, interaction не должен проверять тип цели или искать у неё методы `activate/open/close`: инициатор активирует универсальную interaction ability, а цель сама резолвит семантическое намерение в свою локальную ability.

## Что здесь подтверждено текущим GCA API

В примерах ниже используются существующие контракты:

```text
GameObjectKernel.get_object_context()
GameObjectContext.get_object_handle()
GameObjectContext.create_root_execution_context(...)
GameObjectContext.get_capability(...)

GameAbilities.advance_time(...)
GameAbilities.activate(GameAbilityActivationRequest)

GameAbilityOperation.execute(GameAbilities, GameAbilityExecution)
GameAbilityExecution.get_request()
GameAbilityExecution.get_execution_context()

GameInteractionAbilityOperation
GameInteractionReaction
GameInteractionRequest
GameInteractionTarget

GameTargetingService.query_sphere(...)
GameDamageRequest.new(...)
GameDamageReceiver.apply_damage(...)

GamePlayerInputSource.attach(...)
GamePlayerInputSource.request_control()
GameMockAIControlSource.attach(...)
GameMockAIControlSource.request_control()
GameMockAIControlSource.move(...)
GameMockAIControlSource.stop(...)
```

Два integration-point намеренно не выдуманы:

1. точное событие `GameDeathPolicy`, к которому вы захотите подключить `explode()`/`die()`, зависит от публичного API текущей версии компонента и wiring сцены;
2. при удалении динамической мины используйте публичный unregister API вашего текущего `GameObjectResolver`. Основной tutorial специально требует симметричную регистрацию, но не фиксирует неподтверждённое имя метода.

То же касается наложения Burning: в основном tutorial описан правильный pipeline, но конкретная сигнатура `GameEffects` для application там не зафиксирована. Поэтому здесь нет придуманного `apply_effect(...)`.

---

# 1. `game_simple_scene.gd`

Путь:

```text
res://content/gameplay/simple_scene/world/game_simple_scene.gd
```

```gdscript
extends Node3D
class_name GameSimpleScene

# ======== EXPORT =========
@export var object_resolver: GameObjectResolver = null
@export var targeting_service: GameTargetingService = null
@export var spawned_mines: Node3D = null
@export var mine_scene: PackedScene = null
@export var player: GamePlayerSimple = null
@export var monster: GameMonsterSimple = null
@export var patrol_points_root: Node3D = null

# ======= OVERRIDE =======
func _ready() -> void:
	_wire_player()
	_wire_monster()
	_register_static_objects()

# ====== HELPERS ========
func _wire_player() -> void:
	if player == null:
		return

	player.targeting_service = targeting_service

	if not player.mine_spawn_requested.is_connected(_on_player_mine_spawn_requested):
		player.mine_spawn_requested.connect(_on_player_mine_spawn_requested)

func _wire_monster() -> void:
	if monster == null:
		return

	monster.targeting_service = targeting_service

	if player != null:
		monster.set_target(player)

	var patrol_points: Array[Marker3D] = []

	if patrol_points_root != null:
		for child: Node in patrol_points_root.get_children():
			var marker: Marker3D = child as Marker3D
			if marker != null:
				patrol_points.append(marker)

	monster.set_patrol_points(patrol_points)

func _register_static_objects() -> void:
	if player != null:
		_register_kernel(player.kernel)

	if monster != null:
		_register_kernel(monster.kernel)

func _register_kernel(kernel: GameObjectKernel) -> void:
	if object_resolver == null or kernel == null:
		return

	var context: GameObjectContext = kernel.get_object_context()
	if context == null:
		return

	var handle: GameObjectHandle = context.get_object_handle()
	if handle == null:
		return

	object_resolver.register_handle(handle)

func _on_player_mine_spawn_requested(
	owner_handle: GameObjectHandle,
	spawn_transform: Transform3D
) -> void:
	if mine_scene == null or spawned_mines == null:
		return

	var mine: GameMineSimple = mine_scene.instantiate() as GameMineSimple
	if mine == null:
		return

	mine.owner_handle = owner_handle
	mine.instigator_handle = owner_handle
	mine.targeting_service = targeting_service
	mine.global_transform = spawn_transform

	spawned_mines.add_child(mine)
	_register_kernel(mine.kernel)
	mine.arm_after_delay()
```

### Что назначить в Inspector

```text
object_resolver     -> WorldServices/GameObjectResolver
targeting_service   -> WorldServices/GameTargetingService
spawned_mines       -> SpawnedMines
mine_scene          -> prop_mine_simple.tscn
player              -> Player
monster             -> Monster
patrol_points_root  -> PatrolPoints
```

При удалении runtime-мины добавьте симметричный unregister через публичный API resolver вашей текущей версии GCA.

---

# 2. `game_player_simple.gd`

Путь:

```text
res://content/gameplay/simple_scene/player/game_player_simple.gd
```

Минимальный dodge ниже сделан как короткое collision-aware перемещение через `move_and_collide()`. Это **учебный fallback**, чтобы файл был самодостаточным. Production-вариант из основного tutorial должен временно preempt movement channel через control layer и затем обязательно вернуть владение.

Локальное тиканье ability/effect/queue здесь оставлено намеренно. Владелец подсцены сам контролирует scheduler advancement, что удобно для профилирования и не заставляет весь проект использовать один глобальный runtime driver.

```gdscript
extends CharacterBody3D
class_name GamePlayerSimple

signal mine_spawn_requested(
	owner_handle: GameObjectHandle,
	spawn_transform: Transform3D
)
signal player_died()

# ======== EXPORT =========
@export var kernel: GameObjectKernel = null
@export var control_arbiter: GameControlArbiter = null
@export var control_endpoint: GameControlEndpoint = null
@export var player_input_source: GamePlayerInputSource = null
@export var abilities: GameAbilities = null
@export var effects: GameEffects = null
@export var targeting_service: GameTargetingService = null
@export var mine_placement_marker: Marker3D = null
@export_range(0.0, 10.0, 0.1) var simple_dodge_distance: float = 4.0

# ======== PRIVATE VAR ======
var _control_attached: bool = false
var _dead: bool = false

# ======= OVERRIDE =======
func _ready() -> void:
	_attach_player_control()

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

func _unhandled_input(event: InputEvent) -> void:
	if _dead:
		return

	if event.is_action_pressed(&"attack"):
		_activate_attack()
	elif event.is_action_pressed(&"dodge"):
		_activate_dodge()
	elif event.is_action_pressed(&"place_mine"):
		_activate_place_mine()

# ====== HELPERS ========
func _attach_player_control() -> void:
	if _control_attached:
		return
	if kernel == null or control_arbiter == null or control_endpoint == null:
		return
	if player_input_source == null or kernel.get_object_context() == null:
		return

	player_input_source.set_execution_context_factory(
		func(cause: StringName, label: String) -> GameExecutionContext:
			return kernel.get_object_context().create_root_execution_context(
				cause,
				label
			)
	)

	var result: GameCommandResult = player_input_source.attach(
		control_endpoint,
		control_arbiter
	)

	if not result.is_success():
		return

	player_input_source.request_control()
	_control_attached = true

func _activate_attack() -> void:
	var payload: Dictionary = {
		"actor_node": self,
		"targeting_service": targeting_service,
	}
	activate_ability(&"simple.ability.player.attack", payload)

func _activate_dodge() -> void:
	var payload: Dictionary = {
		"dodge_callable": _perform_simple_dodge,
	}
	activate_ability(&"simple.ability.player.dodge", payload)

func _activate_place_mine() -> void:
	var payload: Dictionary = {
		"spawn_mine_callable": _request_mine_spawn,
	}
	activate_ability(&"simple.ability.player.place_mine", payload)

func _perform_simple_dodge() -> GameCommandResult:
	var direction: Vector3 = -global_transform.basis.z
	direction.y = 0.0

	if direction.is_zero_approx():
		return GameCommandResult.rejected_temporary(
			&"simple_dodge_no_direction",
			"Simple dodge has no valid direction."
		)

	move_and_collide(direction.normalized() * simple_dodge_distance)
	return GameCommandResult.success_changed(&"simple_dodge_completed")

func _request_mine_spawn() -> GameCommandResult:
	if kernel == null or kernel.get_object_context() == null:
		return GameCommandResult.rejected_temporary(
			&"simple_mine_owner_unresolved",
			"Player context is unresolved."
		)

	if mine_placement_marker == null:
		return GameCommandResult.configuration_error(
			&"simple_mine_marker_missing",
			"MinePlacementMarker is not configured."
		)

	var owner_handle: GameObjectHandle = (
		kernel.get_object_context().get_object_handle()
	)

	mine_spawn_requested.emit(
		owner_handle,
		mine_placement_marker.global_transform
	)

	return GameCommandResult.success_changed(&"simple_mine_spawn_requested")

# ====== PUBLIC ========
func activate_ability(
	ability_id: StringName,
	activation_payload: Dictionary = {}
) -> GameCommandResult:
	if abilities == null or kernel == null:
		return GameCommandResult.configuration_error(
			&"simple_player_ability_dependencies_missing",
			"Player ability dependencies are not configured."
		)

	var context: GameObjectContext = kernel.get_object_context()
	if context == null:
		return GameCommandResult.rejected_temporary(
			&"simple_player_context_unresolved",
			"Player context is unresolved."
		)

	var execution_context: GameExecutionContext = (
		context.create_root_execution_context(
			&"simple.player.ability",
			"Player ability activation"
		)
	)

	var owner_handle: GameObjectHandle = context.get_object_handle()
	var request := GameAbilityActivationRequest.new(
		ability_id,
		owner_handle,
		execution_context,
		owner_handle
	)
	request.set_activation_payload(activation_payload)

	return abilities.activate(request)

func mark_dead() -> void:
	if _dead:
		return

	_dead = true
	player_died.emit()
```

`mark_dead()` — явная точка, к которой подключается ваш death bridge/policy. Не проверяйте health каждый physics frame.

> `interact` намеренно отсутствует в `_unhandled_input()`: production interaction подключается как обычный `GameAbilityInputBinding` (`interact → slot.interaction`) и активирует универсальную `simple.ability.player.interact` через control/loadout pipeline.

---

# 3. `game_attack_operation_simple.gd`

Путь:

```text
res://content/gameplay/simple_scene/abilities/game_attack_operation_simple.gd
```

Один класс можно переиспользовать для Player и Monster, создав **два разных operation resource** с разными параметрами.

```gdscript
@tool
extends GameAbilityOperation
class_name GameAttackOperationSimple

# ======== EXPORT =========
@export_range(0.1, 20.0, 0.1) var attack_radius: float = 2.0
@export_range(0.0, 10000.0, 0.1) var attack_damage: float = 25.0
@export var required_tags: Array[StringName] = []
@export var damage_tags: Array[StringName] = [&"damage.melee"]

# ====== PUBLIC ========
func execute(
	_abilities: GameAbilities,
	execution: GameAbilityExecution
) -> GameCommandResult:
	if execution == null or execution.get_request() == null:
		return GameCommandResult.configuration_error(
			&"simple_attack_execution_missing",
			"Attack execution is missing."
		)

	var request: GameAbilityActivationRequest = execution.get_request()
	var payload: Dictionary = request.get_activation_payload()
	var actor: Node3D = payload.get("actor_node") as Node3D
	var targeting_service: GameTargetingService = (
		payload.get("targeting_service") as GameTargetingService
	)

	if actor == null or targeting_service == null:
		return GameCommandResult.configuration_error(
			&"simple_attack_dependencies_missing",
			"Attack actor or targeting service is missing."
		)

	var source_handle: GameObjectHandle = request.get_owner_handle()
	if source_handle == null or not source_handle.is_resolved():
		return GameCommandResult.rejected_temporary(
			&"simple_attack_owner_unresolved",
			"Attack owner handle is unresolved."
		)

	var excluded_ids: Array[StringName] = [
		source_handle.get_stable_id()
	]

	var query: Dictionary = targeting_service.query_sphere(
		actor.global_position,
		attack_radius,
		GameCapabilityIds.DAMAGE_RECEIVER,
		required_tags,
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

		var damage_request := GameDamageRequest.new(
			source_handle,
			source_handle,
			target_handle,
			attack_damage,
			damage_tags,
			execution.get_execution_context()
		)

		if receiver.apply_damage(damage_request).is_success():
			affected_count += 1

	if affected_count <= 0:
		return GameCommandResult.success_unchanged(&"simple_attack_no_targets")

	return GameCommandResult.success_changed(&"simple_attack_applied")

func is_valid() -> bool:
	return attack_radius > 0.0 and attack_damage >= 0.0
```

Настройка Player operation:

```text
attack_radius = 2.0
attack_damage = 25
required_tags = [faction.monster]
damage_tags   = [damage.melee]
```

Настройка Monster operation:

```text
attack_radius = 1.8
attack_damage = 15
required_tags = [faction.player]
damage_tags   = [damage.melee]
```

---

# 4. `game_dodge_operation_simple.gd`

Путь:

```text
res://content/gameplay/simple_scene/abilities/game_dodge_operation_simple.gd
```

Operation не двигает CharacterBody напрямую. Она просит owner-level glue выполнить конкретный dodge. Так Resource не хранит ссылку на конкретный Node сцены.

```gdscript
@tool
extends GameAbilityOperation
class_name GameDodgeOperationSimple

# ====== PUBLIC ========
func execute(
	_abilities: GameAbilities,
	execution: GameAbilityExecution
) -> GameCommandResult:
	if execution == null or execution.get_request() == null:
		return GameCommandResult.configuration_error(
			&"simple_dodge_execution_missing",
			"Dodge execution is missing."
		)

	var payload: Dictionary = (
		execution.get_request().get_activation_payload()
	)
	var dodge_callable: Callable = payload.get(
		"dodge_callable",
		Callable()
	)

	if not dodge_callable.is_valid():
		return GameCommandResult.configuration_error(
			&"simple_dodge_callable_missing",
			"Dodge callable is missing."
		)

	var result: Variant = dodge_callable.call()
	var command_result: GameCommandResult = result as GameCommandResult

	if command_result == null:
		return GameCommandResult.configuration_error(
			&"simple_dodge_result_invalid",
			"Dodge callable must return GameCommandResult."
		)

	return command_result
```

Production evolution:

```text
GameDodgeOperationSimple
→ request/preempt movement control
→ dash over duration
→ optional status.invulnerable
→ release movement control
→ GameControlArbiter restores previous owner
```

Не добавляйте i-frames, пока не проверили, что control channel всегда освобождается.

---

# 5. `game_place_mine_operation_simple.gd`

Путь:

```text
res://content/gameplay/simple_scene/abilities/game_place_mine_operation_simple.gd
```

```gdscript
@tool
extends GameAbilityOperation
class_name GamePlaceMineOperationSimple

# ====== PUBLIC ========
func execute(
	_abilities: GameAbilities,
	execution: GameAbilityExecution
) -> GameCommandResult:
	if execution == null or execution.get_request() == null:
		return GameCommandResult.configuration_error(
			&"simple_place_mine_execution_missing",
			"Place-mine execution is missing."
		)

	var payload: Dictionary = (
		execution.get_request().get_activation_payload()
	)
	var spawn_callable: Callable = payload.get(
		"spawn_mine_callable",
		Callable()
	)

	if not spawn_callable.is_valid():
		return GameCommandResult.configuration_error(
			&"simple_mine_spawn_callable_missing",
			"Mine spawn callable is missing."
		)

	var result: Variant = spawn_callable.call()
	var command_result: GameCommandResult = result as GameCommandResult

	if command_result == null:
		return GameCommandResult.configuration_error(
			&"simple_mine_spawn_result_invalid",
			"Mine spawn callable must return GameCommandResult."
		)

	return command_result
```

Здесь operation не ищет `MainScene` через `get_parent()`. Player сообщает запрос наверх signal-ом, а `GameSimpleScene` создаёт mine instance.

---

# 6. `game_monster_simple.gd`

Путь:

```text
res://content/gameplay/simple_scene/monster/game_monster_simple.gd
```

```gdscript
extends CharacterBody3D
class_name GameMonsterSimple

enum State {
	PATROL,
	CHASE,
	ATTACK,
	DEAD,
}

signal state_changed(state: State)
signal monster_died()

# ======== EXPORT =========
@export var kernel: GameObjectKernel = null
@export var control_arbiter: GameControlArbiter = null
@export var control_endpoint: GameControlEndpoint = null
@export var ai_control_source: GameMockAIControlSource = null
@export var abilities: GameAbilities = null
@export var effects: GameEffects = null
@export var navigation_agent: NavigationAgent3D = null
@export var targeting_service: GameTargetingService = null
@export_range(0.1, 50.0, 0.1) var detect_distance: float = 10.0
@export_range(0.1, 50.0, 0.1) var lose_distance: float = 14.0
@export_range(0.1, 10.0, 0.1) var attack_distance: float = 1.8

# ======== PRIVATE VAR ======
var _state: State = State.PATROL
var _control_attached: bool = false
var _target: Node3D = null
var _patrol_points: Array[Marker3D] = []
var _patrol_index: int = 0

# ======= OVERRIDE =======
func _ready() -> void:
	_attach_ai_control()

func _physics_process(delta: float) -> void:
	_tick_ai()

	if abilities != null:
		abilities.advance_time(delta)

	if effects != null and kernel != null and kernel.get_object_context() != null:
		var execution_context: GameExecutionContext = (
			kernel.get_object_context().create_root_execution_context(
				&"simple.monster.tick",
				"Simple monster scheduler"
			)
		)
		effects.advance_time(delta, execution_context)

	if kernel != null:
		kernel.process_execution_queue()

# ====== HELPERS ========
func _attach_ai_control() -> void:
	if _control_attached:
		return
	if kernel == null or control_arbiter == null or control_endpoint == null:
		return
	if ai_control_source == null or kernel.get_object_context() == null:
		return

	var result: GameCommandResult = ai_control_source.attach(
		control_endpoint,
		control_arbiter
	)

	if not result.is_success():
		return

	ai_control_source.request_control()
	_control_attached = true

func _tick_ai() -> void:
	if not _control_attached or _state == State.DEAD:
		return
	if kernel == null or kernel.get_object_context() == null:
		return

	var target_distance: float = INF
	if _target != null:
		target_distance = global_position.distance_to(_target.global_position)

	match _state:
		State.PATROL:
			if _target != null and target_distance <= detect_distance:
				_set_state(State.CHASE)
				return
			_tick_patrol()

		State.CHASE:
			if _target == null or target_distance > lose_distance:
				_set_state(State.PATROL)
				return
			if target_distance <= attack_distance:
				_set_state(State.ATTACK)
				return
			_move_toward(_target.global_position)

		State.ATTACK:
			_stop_movement()
			if _target == null or target_distance > attack_distance:
				_set_state(State.CHASE)
				return
			_activate_attack()

func _tick_patrol() -> void:
	if _patrol_points.is_empty():
		_stop_movement()
		return

	var marker: Marker3D = _patrol_points[_patrol_index]
	if marker == null:
		_advance_patrol_point()
		return

	if global_position.distance_to(marker.global_position) <= 0.6:
		_advance_patrol_point()
		return

	_move_toward(marker.global_position)

func _advance_patrol_point() -> void:
	if _patrol_points.is_empty():
		return
	_patrol_index = (_patrol_index + 1) % _patrol_points.size()

func _move_toward(target_position: Vector3) -> void:
	if navigation_agent == null:
		return

	navigation_agent.target_position = target_position
	var next_position: Vector3 = navigation_agent.get_next_path_position()
	var direction: Vector3 = next_position - global_position
	direction.y = 0.0

	if direction.is_zero_approx():
		_stop_movement()
		return

	var context: GameExecutionContext = (
		kernel.get_object_context().create_root_execution_context(
			&"simple.monster.move",
			"Monster movement"
		)
	)
	ai_control_source.move(direction.normalized(), 1.0, context)

func _stop_movement() -> void:
	if ai_control_source == null or kernel == null:
		return
	if kernel.get_object_context() == null:
		return

	var context: GameExecutionContext = (
		kernel.get_object_context().create_root_execution_context(
			&"simple.monster.stop",
			"Monster stop"
		)
	)
	ai_control_source.stop(context)

func _activate_attack() -> void:
	if abilities == null or kernel == null:
		return

	var context: GameObjectContext = kernel.get_object_context()
	if context == null:
		return

	var execution_context: GameExecutionContext = (
		context.create_root_execution_context(
			&"simple.monster.attack",
			"Monster attack"
		)
	)
	var owner_handle: GameObjectHandle = context.get_object_handle()
	var request := GameAbilityActivationRequest.new(
		&"simple.ability.monster.attack",
		owner_handle,
		execution_context,
		owner_handle
	)
	request.set_activation_payload({
		"actor_node": self,
		"targeting_service": targeting_service,
	})

	abilities.activate(request)

func _set_state(value: State) -> void:
	if _state == value:
		return
	_state = value
	state_changed.emit(_state)

# ====== PUBLIC ========
func set_target(value: Node3D) -> void:
	_target = value

func set_patrol_points(value: Array[Marker3D]) -> void:
	_patrol_points = value.duplicate()
	_patrol_index = 0

func mark_dead() -> void:
	if _state == State.DEAD:
		return

	_set_state(State.DEAD)
	_stop_movement()
	monster_died.emit()
```

Cooldown ability должен ограничивать частоту `_activate_attack()`. AI может просить activation каждый physics tick в `ATTACK`, а `GameAbilities` будет возвращать structured rejection, пока cooldown активен.

---

# 7. Дверь: target-owned abilities вместо command dispatcher

Главное правило этого примера:

```text
Character / NPC / AI
→ ability.interact
→ semantic interaction request
→ Door.GameInteractionTarget
→ Door reaction
→ Door.GameAbilities
→ ability.door.open / ability.door.close
```

Ни `GamePlayerInputSource`, ни `GameInteractionSource`, ни другой внешний код не проверяет `GameDoorSimple`, не вызывает `has_method()` и не знает методов двери.

## 7.1. `game_door_simple.gd`

Путь:

```text
res://content/gameplay/simple_scene/door/game_door_simple.gd
```

```gdscript
extends AnimatableBody3D
class_name GameDoorSimple

signal door_opened()
signal door_closed()

# ======= CONSTS =========
const OPEN_TAG: StringName = &"state.open"
const STATE_SOURCE_ID: StringName = &"simple.door.state"

# ======== EXPORT =========
@export var hinge: Node3D = null
@export var tags: GameTagContainer = null
@export_range(0.0, 170.0, 1.0) var open_angle_degrees: float = 95.0

# ======== PRIVATE VAR ======
var _is_open: bool = false
var _open_tag_handle: GameTagSourceHandle = null

# ======= OVERRIDE =======
func _ready() -> void:
	_refresh_visual()

# ====== HELPERS ========
func _refresh_visual() -> void:
	if hinge != null:
		hinge.rotation_degrees.y = open_angle_degrees if _is_open else 0.0

func _add_open_tag() -> bool:
	if tags == null:
		return false
	if _open_tag_handle != null and _open_tag_handle.is_valid():
		return true
	_open_tag_handle = tags.add_tag(OPEN_TAG, STATE_SOURCE_ID)
	return _open_tag_handle != null

func _remove_open_tag() -> void:
	if tags == null or _open_tag_handle == null:
		return
	tags.remove_tag(_open_tag_handle)
	_open_tag_handle = null

# ====== PUBLIC ========
## Target-local state API. Interaction systems never call this method directly;
## only door-owned ability operations do.
func set_open(value: bool) -> GameCommandResult:
	if value == _is_open:
		return GameCommandResult.success_unchanged(
			&"door_already_open" if value else &"door_already_closed"
		)

	if value and not _add_open_tag():
		return GameCommandResult.configuration_error(
			&"door_open_tag_failed",
			"Door requires gameplay tag 'state.open' in its tag catalog."
		)
	if not value:
		_remove_open_tag()

	_is_open = value
	_refresh_visual()
	if _is_open:
		door_opened.emit()
		return GameCommandResult.success_changed(&"door_opened")

	door_closed.emit()
	return GameCommandResult.success_changed(&"door_closed")

func is_open() -> bool:
	return _is_open
```

Здесь есть `set_open()`, но это **не interaction dispatcher** и не публичный protocol для внешнего мира. Это локальная реализация состояния конкретной двери. Generic interaction code никогда не знает об этом методе.

## 7.2. `game_door_set_open_operation_simple.gd`

Путь:

```text
res://content/gameplay/simple_scene/door/game_door_set_open_operation_simple.gd
```

```gdscript
@tool
extends GameAbilityOperation
class_name GameDoorSetOpenOperationSimple

# ======== EXPORT =========
@export var open: bool = true

# ====== PUBLIC ========
func execute(
	_abilities: GameAbilities,
	execution: GameAbilityExecution
) -> GameCommandResult:
	if execution == null or execution.get_request() == null:
		return GameCommandResult.configuration_error(
			&"door_execution_missing",
			"Door ability execution is incomplete."
		)

	var owner_handle: GameObjectHandle = (
		execution.get_request().get_owner_handle()
	)
	if owner_handle == null or not owner_handle.is_resolved():
		return GameCommandResult.invalid_target(
			"Door ability owner is unresolved."
		)

	var door: GameDoorSimple = owner_handle.get_root() as GameDoorSimple
	if door == null:
		return GameCommandResult.invalid_target(
			"Door ability owner root does not provide GameDoorSimple state."
		)

	return door.set_open(open)
```

Это game-specific operation **локальной door ability**. Тип `GameDoorSimple` известен только реализации самой двери. Interaction framework и инициатор взаимодействия его не знают.

## 7.3. Door abilities

Создайте две `GameAbilityDefinition`:

```text
simple.ability.door.open
    blocked_owner_tags = [state.open]
    operations:
        GameDoorSetOpenOperationSimple(open = true)

simple.ability.door.close
    required_owner_tags = [state.open]
    operations:
        GameDoorSetOpenOperationSimple(open = false)
```

Добавьте их в `Door/GameObjectKernel/GameAbilities.initial_abilities`.

Обязательно добавьте `state.open` в `GameTagCatalog`, назначенный двери. Именно ability requirements, а не `_refresh_offers()`, определяют текущее состояние доступности `open/close`.

## 7.4. Door reactions

В `GameInteractionTarget.reactions` назначьте два `GameInteractionReaction`:

```text
Open reaction
    offer_id             = simple.door.open
    intent_id            = open
    verb_id              = verb.open
    ability_id           = simple.ability.door.open
    priority             = 50
    default_candidate    = true

Close reaction
    offer_id             = simple.door.close
    intent_id            = close
    verb_id              = verb.close
    ability_id           = simple.ability.door.close
    priority             = 50
    default_candidate    = true
```

Когда дверь закрыта, `simple.ability.door.close` не проходит `required_owner_tags`, поэтому `query_offers()` публикует только `open`. После успешного открытия появляется `state.open`, `open` становится недоступен, а `close` — доступен.

Никакого ручного:

```text
_refresh_offers()
execute_door_command()
if target is Door
has_method("open")
```

не требуется.

## 7.5. Обычное и направленное взаимодействие

У Player/NPC создайте универсальную ability:

```text
simple.ability.player.interact
└── GameInteractionAbilityOperation
```

Обычная кнопка interaction активирует её без semantic intent:

```text
interact
→ slot.interaction
→ simple.ability.player.interact
→ focused target
→ default currently available reaction
```

Для закрытой двери получится `open`, для открытой — `close`.

AI/cutscene может активировать **ту же ability**, но передать намерение:

```gdscript
request.set_activation_payload({
	GameInteractionRequest.ACTIVATION_INTENT_KEY: &"open",
})
```

Тогда `GameInteractionTarget` рассматривает только реакции `intent_id == open`. Если дверь уже открыта или открывается и `door.open` недоступна по requirements/concurrency, запрос получит rejection от `door.open`; он **не превратится в close**.

---

# 8. `game_barrel_simple.gd`

Путь:

```text
res://content/gameplay/simple_scene/barrel/game_barrel_simple.gd
```

```gdscript
extends StaticBody3D
class_name GameBarrelSimple

signal barrel_exploded(affected_count: int)

# ======== EXPORT =========
@export var kernel: GameObjectKernel = null
@export var targeting_service: GameTargetingService = null
@export_range(0.1, 20.0, 0.1) var explosion_radius: float = 3.5
@export_range(0.0, 10000.0, 0.1) var explosion_damage: float = 45.0

# ======== PRIVATE VAR ======
var _exploded: bool = false

# ====== PUBLIC ========
func explode(instigator_handle: GameObjectHandle = null) -> void:
	if _exploded:
		return
	_exploded = true

	if kernel == null or kernel.get_object_context() == null:
		barrel_exploded.emit(0)
		return

	var context: GameObjectContext = kernel.get_object_context()
	var barrel_handle: GameObjectHandle = context.get_object_handle()
	var effective_instigator: GameObjectHandle = instigator_handle

	if effective_instigator == null:
		effective_instigator = barrel_handle

	var execution_context: GameExecutionContext = (
		context.create_root_execution_context(
			&"simple.barrel.explosion",
			"Barrel explosion"
		)
	)

	var affected_count: int = apply_radial_damage(
		barrel_handle,
		effective_instigator,
		global_position,
		explosion_radius,
		explosion_damage,
		[&"damage.explosion"],
		execution_context
	)

	barrel_exploded.emit(affected_count)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	call_deferred("queue_free")

func apply_radial_damage(
	source_handle: GameObjectHandle,
	instigator_handle: GameObjectHandle,
	center: Vector3,
	radius: float,
	damage: float,
	damage_tags: Array[StringName],
	execution_context: GameExecutionContext
) -> int:
	if targeting_service == null or source_handle == null:
		return 0

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

		var damage_request := GameDamageRequest.new(
			source_handle,
			instigator_handle,
			target_handle,
			damage,
			damage_tags,
			execution_context
		)

		if receiver.apply_damage(damage_request).is_success():
			affected_count += 1

	return affected_count
```

Подключите death transition бочки к `explode()` через публичное событие/bridge вашего текущего `GameDeathPolicy`. Guard `_exploded` устанавливается **до** radial damage, поэтому chain reaction не сможет повторно взорвать ту же бочку.

---

# 9. `game_mine_simple.gd`

Путь:

```text
res://content/gameplay/simple_scene/mine/game_mine_simple.gd
```

```gdscript
extends StaticBody3D
class_name GameMineSimple

enum State {
	PLACED,
	ARMED,
	EXPLODED,
}

signal mine_armed()
signal mine_exploded(affected_count: int)

# ======== EXPORT =========
@export var kernel: GameObjectKernel = null
@export var targeting_service: GameTargetingService = null
@export var trigger_area: Area3D = null
@export var trigger_collision: CollisionShape3D = null
@export_range(0.0, 5.0, 0.01) var arming_delay: float = 0.35
@export_range(0.1, 20.0, 0.1) var explosion_radius: float = 3.0
@export_range(0.0, 10000.0, 0.1) var explosion_damage: float = 50.0

# ======== PUBLIC VAR ======
var owner_handle: GameObjectHandle = null
var instigator_handle: GameObjectHandle = null

# ======== PRIVATE VAR ======
var _state: State = State.PLACED

# ======= OVERRIDE =======
func _ready() -> void:
	if trigger_collision != null:
		trigger_collision.set_deferred("disabled", true)

	if trigger_area != null:
		if not trigger_area.body_entered.is_connected(_on_trigger_body_entered):
			trigger_area.body_entered.connect(_on_trigger_body_entered)

# ====== HELPERS ========
func _on_trigger_body_entered(body: Node3D) -> void:
	if _state != State.ARMED or body == null:
		return

	var body_kernel: GameObjectKernel = body.get("kernel") as GameObjectKernel
	if body_kernel == null or body_kernel.get_object_context() == null:
		return

	var body_handle: GameObjectHandle = (
		body_kernel.get_object_context().get_object_handle()
	)
	if body_handle == null or not body_handle.is_resolved():
		return

	if owner_handle != null:
		if body_handle.get_stable_id() == owner_handle.get_stable_id():
			return

	explode(body_handle)

# ====== PUBLIC ========
func arm_after_delay() -> void:
	if _state != State.PLACED:
		return

	if arming_delay > 0.0:
		await get_tree().create_timer(arming_delay).timeout

	if not is_inside_tree() or _state != State.PLACED:
		return

	_state = State.ARMED
	if trigger_collision != null:
		trigger_collision.set_deferred("disabled", false)
	mine_armed.emit()

func explode(trigger_instigator: GameObjectHandle = null) -> void:
	if _state == State.EXPLODED:
		return

	_state = State.EXPLODED
	if trigger_collision != null:
		trigger_collision.set_deferred("disabled", true)

	if kernel == null or kernel.get_object_context() == null:
		mine_exploded.emit(0)
		return

	var context: GameObjectContext = kernel.get_object_context()
	var mine_handle: GameObjectHandle = context.get_object_handle()
	var effective_instigator: GameObjectHandle = trigger_instigator

	if effective_instigator == null:
		effective_instigator = instigator_handle
	if effective_instigator == null:
		effective_instigator = mine_handle

	var execution_context: GameExecutionContext = (
		context.create_root_execution_context(
			&"simple.mine.explosion",
			"Mine explosion"
		)
	)

	var affected_count: int = apply_radial_damage(
		mine_handle,
		effective_instigator,
		global_position,
		explosion_radius,
		explosion_damage,
		[&"damage.explosion"],
		execution_context
	)

	mine_exploded.emit(affected_count)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	call_deferred("queue_free")

func apply_radial_damage(
	source_handle: GameObjectHandle,
	instigator: GameObjectHandle,
	center: Vector3,
	radius: float,
	damage: float,
	damage_tags: Array[StringName],
	execution_context: GameExecutionContext
) -> int:
	if targeting_service == null or source_handle == null:
		return 0

	var excluded_ids: Array[StringName] = [
		source_handle.get_stable_id()
	]

	if owner_handle != null:
		var owner_id: StringName = owner_handle.get_stable_id()
		if not excluded_ids.has(owner_id):
			excluded_ids.append(owner_id)

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

		var damage_request := GameDamageRequest.new(
			source_handle,
			instigator,
			target_handle,
			damage,
			damage_tags,
			execution_context
		)

		if receiver.apply_damage(damage_request).is_success():
			affected_count += 1

	return affected_count
```

### Почему `body` не игнорируется

`body_entered(body)` используется, чтобы получить реального instigator trigger-а. Это исправляет архитектурную ошибку вида:

```gdscript
func _on_body_entered(_body: Node3D) -> void:
	trigger()
```

При таком варианте мина теряет информацию о том, кто её активировал.

### Burning

После успешного explosion hit добавьте вторую, отдельную операцию:

```text
explosion hit
├── GameDamageRequest(damage.explosion)
└── GameEffects application(simple.effect.burning)
```

Не вставляйте сюда выдуманный вызов `GameEffects`. Сначала используйте фактический application API вашей текущей версии GCA, затем сохраните тот же causal `GameExecutionContext`.

### Удаление мины

Перед фактическим удалением runtime-мины world-level owner должен снять её handle с `GameObjectResolver` публичным unregister API текущей версии. Сам объект не должен искать resolver через `get_parent()`.

---

# 10. Inspector/resource wiring abilities

В GCA Data Studio создайте definitions:

```text
simple.ability.player.attack
simple.ability.player.dodge
simple.ability.player.place_mine
simple.ability.player.interact
simple.ability.monster.attack
simple.ability.door.open
simple.ability.door.close
```

Назначьте operations:

```text
Player Attack
└── GameAttackOperationSimple
    attack_radius = 2.0
    attack_damage = 25
    required_tags = [faction.monster]

Player Dodge
└── GameDodgeOperationSimple

Player Place Mine
└── GamePlaceMineOperationSimple

Player Interact
└── GameInteractionAbilityOperation

Monster Attack
└── GameAttackOperationSimple
    attack_radius = 1.8
    attack_damage = 15
    required_tags = [faction.player]

Door Open
├── blocked_owner_tags = [state.open]
└── GameDoorSetOpenOperationSimple
    open = true

Door Close
├── required_owner_tags = [state.open]
└── GameDoorSetOpenOperationSimple
    open = false
```

Cooldown задавайте в `GameAbilityDefinition`, а не собственным timer в Player/Monster glue:

```text
player attack  = 0.45 s
player dodge   = 0.8 s
place mine     = 2.0 s
monster attack = 1.0 s
```

Для двери добавьте `state.open` в назначенный `GameTagCatalog`.

---

# 11. Что подключить вручную в сценах

## Player

```text
GamePlayerSimple.kernel                -> GameObjectKernel
GamePlayerSimple.control_arbiter       -> GameControlArbiter
GamePlayerSimple.control_endpoint      -> GameControlEndpoint
GamePlayerSimple.player_input_source   -> GamePlayerInputSource
GamePlayerSimple.abilities             -> GameAbilities
GamePlayerSimple.effects               -> GameEffects
GamePlayerSimple.mine_placement_marker -> MinePlacementMarker
```

В `GameAbilities.initial_abilities` добавьте `simple.ability.player.interact`.

В `GameAbilityLoadout` добавьте логический interaction slot, а в `GamePlayerInputSource.ability_input_bindings`:

```text
input_action = interact
slot_id      = slot.interaction
```

То есть `GamePlayerInputSource` не содержит отдельного знания о двери и не вызывает interaction напрямую: `interact` — такая же кнопка активации ability slot, как attack/dodge.

InputMap для прототипа:

```text
attack     = Mouse1
dodge      = Space
place_mine = Q
interact   = E
```

## Monster

```text
kernel             -> GameObjectKernel
control_arbiter    -> GameControlArbiter
control_endpoint   -> GameControlEndpoint
ai_control_source  -> GameMockAIControlSource
abilities          -> GameAbilities
effects            -> GameEffects
navigation_agent   -> NavigationAgent3D
```

NPC/AI, которому тоже нужно взаимодействовать с миром, может иметь тот же `GameInteractionSource` + universal interact ability. Объект также может одновременно иметь `GameInteractionTarget`: source и target не конфликтуют capability registration.

## Door

Рекомендуемое дерево:

```text
Door (AnimatableBody3D, GameDoorSimple)
├── Hinge
│   ├── MeshInstance3D
│   └── CollisionShape3D
└── GameObjectKernel
    ├── GameObjectIdentity
    ├── GameTagContainer
    ├── GameAbilities
    └── GameInteractionTarget
```

Inspector:

```text
GameDoorSimple.hinge -> Hinge
GameDoorSimple.tags  -> GameObjectKernel/GameTagContainer
```

`GameAbilities.initial_abilities`:

```text
simple.ability.door.open
simple.ability.door.close
```

`GameInteractionTarget.reactions`:

```text
open  -> simple.ability.door.open
close -> simple.ability.door.close
```

Никакой `interaction_target` export-ссылки в `GameDoorSimple` больше нет: дверь не вручную переписывает offers.

## Barrel

```text
kernel              -> GameObjectKernel
targeting_service   -> назначает GameSimpleScene
```

## Mine

```text
kernel              -> GameObjectKernel
trigger_area        -> TriggerArea
trigger_collision   -> TriggerArea/CollisionShape3D
targeting_service   -> назначает GameSimpleScene
owner_handle        -> назначает GameSimpleScene при spawn
instigator_handle   -> назначает GameSimpleScene при spawn
```

---

# 12. Минимальный порядок проверки

Проверяйте не всё сразу, а по слоям:

```text
1. World запускается, floor имеет collision.
2. Player двигается через control pipeline.
3. Player handle зарегистрирован resolver-ом.
4. Test GameDamageRequest уменьшает Health через DamageReceiver.
5. Player attack activation проходит через GameAbilities.
6. Attack operation находит Monster через DAMAGE_RECEIVER.
7. Monster patrol/chase работает через AI control source.
8. Monster attack damage идёт тем же pipeline.
9. Interact slot активирует universal interaction ability.
10. Closed Door query показывает только intent.open.
11. Default interact на Closed Door активирует door.open.
12. После state.open query показывает только intent.close.
13. Explicit intent.open на уже открытой двери не вызывает door.close.
14. Barrel получает damage и explode() вызывается один раз.
15. PlaceMine ability создаёт runtime mine.
16. Mine не armed первые 0.35 s.
17. body_entered передаёт реального trigger instigator.
18. Mine explosion находит зарегистрированные DAMAGE_RECEIVER цели.
19. После этого отдельно подключается Burning через фактический GameEffects API.
20. Затем подключаются death bridges, presentation и unregister lifecycle.
```

Если шаг не работает, не переходите к следующему. Так проще определить, какой именно контракт нарушен.

---

# 13. Где следующий рефакторинг

В `GameBarrelSimple` и `GameMineSimple` специально оставлен одинаковый учебный `apply_radial_damage()`. Это делает первый прототип прозрачным: вы видите весь путь от world query до `GameDamageRequest`.

Когда этот цикл станет понятен и начнёт повторяться в нескольких mechanics, вынесите его в project-level combat service.

Подробный пример такого следующего шага:

[`example_combat_service.md`](./example_combat_service.md)

Ментальная модель:

```text
Mine / Barrel
→ решают КОГДА взорваться и с какими параметрами

GameCombatService
→ знает КАК выполнить стандартный targeting + damage-request pipeline

GameDamageReceiver
→ знает КАК цель принимает входящий damage request
```

Не переносите в combat service arming мины, AI, дверь, VFX или death state. Иначе он превратится в God object.

---

# 14. Что этот companion намеренно не делает

Он не создаёт:

- `project.godot`;
- бинарные файлы;
- `.godot/imported`;
- готовые `.tscn`;
- готовые `.tres`;
- target-type dispatchers;
- `has_method("activate")` interaction wiring;
- фиктивные GCA API, которых нет в проверенных источниках.

Сцены и data resources собираются вручную по основному [`example_simple_scene.md`](./example_simple_scene.md), а этот файл служит копируемым набором game-specific glue-шаблонов.
