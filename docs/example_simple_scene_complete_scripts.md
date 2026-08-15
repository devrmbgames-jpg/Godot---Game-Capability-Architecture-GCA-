# Цельные скрипты к `example_simple_scene.md` — текущий API

Этот companion содержит game-specific GDScript, совместимый с контрактами, описанными в [`example_simple_scene.md`](./example_simple_scene.md).

Ключевые отличия от старой версии примера:

- нет `_unhandled_input()` для attack/dodge/place-mine;
- нет прямого `GameAbilities.activate()` из Player/AI root;
- нет activation payload с `actor_node`, `targeting_service` или `Callable`;
- статические objects bind-ятся через `GameWorldContext.bind_kernel()`;
- attack operation получает targeting через world port;
- mine создаётся через `GameSpawnService`;
- death подключается к реальному `GameDeathPolicy.died`;
- Burning применяется через реальный `GameEffects.apply_effect()`;
- despawn идёт через `GameSpawnService.despawn()`;
- interaction остаётся generic ability → semantic request → target-owned ability.

> Для статических Player/Monster/Door/Barrels выставьте `GameObjectKernel.auto_initialize = false` в Inspector. Parent world bind-ит их после того, как все scene nodes вошли в tree, и только затем запускает root runtime glue.

---

# 1. `game_simple_scene.gd`

```gdscript
extends Node3D
class_name GameSimpleScene

# ======== EXPORT =========
@export var world_context: GameWorldContext = null
@export var player: GamePlayerSimple = null
@export var monster: GameMonsterSimple = null
@export var door: GameDoorSimple = null
@export var barrels: Array[GameBarrelSimple] = []
@export var patrol_points_root: Node3D = null

# ======= OVERRIDE =======
func _ready() -> void:
	if world_context == null:
		push_error("SimpleScene requires GameWorldContext.")
		return

	if player != null and not _bind_kernel(player.kernel):
		return
	if monster != null and not _bind_kernel(monster.kernel):
		return
	if door != null and not _bind_kernel(door.kernel):
		return
	for barrel: GameBarrelSimple in barrels:
		if barrel != null and not _bind_kernel(barrel.kernel):
			return

	_wire_monster()

	if player != null:
		player.start_runtime()
	if monster != null:
		monster.start_runtime()

# ====== HELPERS ========
func _bind_kernel(kernel: GameObjectKernel) -> bool:
	if kernel == null:
		push_error("SimpleScene contains an object without GameObjectKernel.")
		return false
	var result: GameCommandResult = world_context.bind_kernel(kernel)
	if result.is_success():
		return true
	push_error(
		"Could not bind kernel: %s — %s" % [
			result.get_reason_code(),
			result.get_debug_message(),
		]
	)
	return false

func _wire_monster() -> void:
	if monster == null:
		return
	if player != null:
		monster.set_target(player)

	var points: Array[Marker3D] = []
	if patrol_points_root != null:
		for child: Node in patrol_points_root.get_children():
			var marker: Marker3D = child as Marker3D
			if marker != null:
				points.append(marker)
	monster.set_patrol_points(points)
```

World Inspector:

```text
GameSpawnService.object_resolver = GameObjectResolver
GameSpawnService.default_parent  = SpawnedMines

GameWorldContext.object_resolver         = GameObjectResolver
GameWorldContext.spawn_service           = GameSpawnService
GameWorldContext.targeting_service       = GameTargetingService
GameWorldContext.time_service            = GameTimeService
GameWorldContext.persistence_coordinator = GamePersistenceCoordinator
```

Не вызывайте `object_resolver.register_handle()` после `bind_kernel()`.

---

# 2. `game_player_simple.gd`

Player root больше не знает concrete attack/dodge/mine IDs. Кнопки настраиваются в `GamePlayerInputSource.ability_input_bindings`, а concrete grants — в `GameAbilityLoadout`.

```gdscript
extends CharacterBody3D
class_name GamePlayerSimple

signal player_died()

# ======== EXPORT =========
@export var kernel: GameObjectKernel = null
@export var control_arbiter: GameControlArbiter = null
@export var control_endpoint: GameControlEndpoint = null
@export var player_input_source: GamePlayerInputSource = null
@export var interaction_source: GameInteractionSource = null
@export var abilities: GameAbilities = null
@export var effects: GameEffects = null
@export var death_policy: GameDeathPolicy = null

# ======== PRIVATE VAR ======
var _runtime_started: bool = false
var _dead: bool = false

# ======= OVERRIDE =======
func _physics_process(delta: float) -> void:
	if not _runtime_started:
		return
	if abilities != null:
		abilities.advance_time(delta)
	if effects != null and kernel != null:
		var context: GameObjectContext = kernel.get_object_context()
		if context != null:
			effects.advance_time(
				delta,
				context.create_root_execution_context(
					&"simple.player.effects_tick",
					"Player effects tick"
				)
			)
	if kernel != null:
		kernel.process_execution_queue()

# ====== PUBLIC ========
func start_runtime() -> void:
	if _runtime_started:
		return
	if kernel == null or kernel.get_object_context() == null:
		push_error("Player kernel must be bound before start_runtime().")
		return
	if control_arbiter == null or control_endpoint == null or player_input_source == null:
		push_error("Player control dependencies are incomplete.")
		return

	player_input_source.set_execution_context_factory(
		func(cause: StringName, label: String) -> GameExecutionContext:
			return kernel.get_object_context().create_root_execution_context(cause, label)
	)
	var result: GameCommandResult = player_input_source.attach(
		control_endpoint,
		control_arbiter
	)
	if not result.is_success():
		push_error(result.get_debug_message())
		return
	player_input_source.request_control()

	if death_policy != null and not death_policy.died.is_connected(_on_died):
		death_policy.died.connect(_on_died)
	_runtime_started = true

## Called by a project sensing/raycast adapter after it resolves an interactable handle.
func focus_interaction(target_handle: GameObjectHandle) -> GameCommandResult:
	if interaction_source == null or kernel == null or kernel.get_object_context() == null:
		return GameCommandResult.configuration_error(
			&"interaction_source_missing",
			"Player interaction source is not configured."
		)
	var execution_context: GameExecutionContext = (
		kernel.get_object_context().create_root_execution_context(
			&"simple.player.focus_interaction",
			"Player interaction focus"
		)
	)
	return interaction_source.set_focus(target_handle, execution_context)

# ====== HANDLERS ========
func _on_died(_execution_context: GameExecutionContext) -> void:
	if _dead:
		return
	_dead = true
	if player_input_source != null:
		player_input_source.suspend()
	player_died.emit()
```

Если у `GameControlSource` вашей сцены не требуется отдельный `suspend()` call при смерти, можно вместо него release/cancel control в вашем death orchestration. Смысл примера: реакция происходит от `GameDeathPolicy.died`, а не от polling meter.

Player Inspector data:

```text
GameAbilities.initial_abilities:
- simple.ability.player.attack
- simple.ability.player.dodge
- simple.ability.player.place_mine
- simple.ability.player.interact

GameAbilityLoadout.initial_slots:
- slot.primary     -> attack
- slot.mobility    -> dodge
- slot.utility_1   -> place_mine
- slot.interaction -> interact

GamePlayerInputSource.ability_input_bindings:
- attack     -> slot.primary
- dodge      -> slot.mobility
- place_mine -> slot.utility_1
- interact   -> slot.interaction
```

---

# 3. `game_attack_operation_simple.gd`

Один class используется и Player, и Monster. Разными resources задайте damage/radius/required_tags.

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
	var source_handle: GameObjectHandle = request.get_owner_handle()
	if source_handle == null or not source_handle.is_resolved():
		return GameCommandResult.invalid_target("Attack owner is unresolved.")

	var actor: Node3D = source_handle.get_root() as Node3D
	var source_context: GameObjectContext = source_handle.get_context()
	if actor == null or source_context == null:
		return GameCommandResult.invalid_target("Attack owner root/context is unavailable.")

	var targeting_service: GameTargetingService = (
		source_context.get_world_port(GameWorldPortIds.TARGETING_QUERY)
		as GameTargetingService
	)
	if targeting_service == null:
		return GameCommandResult.configuration_error(
			&"simple_attack_targeting_missing",
			"Owner has no targeting world port."
		)

	var excluded_ids: Array[StringName] = [source_handle.get_stable_id()]
	var query: Dictionary = targeting_service.query_sphere(
		actor.global_position,
		attack_radius,
		GameCapabilityIds.DAMAGE_RECEIVER,
		required_tags,
		excluded_ids
	)
	var affected_count: int = 0

	for value: Variant in query.get("handles", []):
		var target_handle: GameObjectHandle = value as GameObjectHandle
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

	if affected_count == 0:
		return GameCommandResult.success_unchanged(&"simple_attack_no_targets")
	return GameCommandResult.success_changed(
		&"simple_attack_applied",
		affected_count
	)

func is_valid() -> bool:
	return attack_radius > 0.0 and attack_damage >= 0.0
```

---

# 4. `game_dodge_operation_simple.gd`

Это учебный one-step fallback. Он не требует callback в activation payload.

```gdscript
@tool
extends GameAbilityOperation
class_name GameDodgeOperationSimple

@export_range(0.0, 10.0, 0.1) var distance: float = 4.0

func execute(
	_abilities: GameAbilities,
	execution: GameAbilityExecution
) -> GameCommandResult:
	if execution == null or execution.get_request() == null:
		return GameCommandResult.configuration_error(
			&"simple_dodge_execution_missing",
			"Dodge execution is missing."
		)
	var owner_handle: GameObjectHandle = execution.get_request().get_owner_handle()
	if owner_handle == null or not owner_handle.is_resolved():
		return GameCommandResult.invalid_target("Dodge owner is unresolved.")
	var body: CharacterBody3D = owner_handle.get_root() as CharacterBody3D
	if body == null:
		return GameCommandResult.invalid_target(
			"Simple dodge requires CharacterBody3D owner root."
		)
	var direction: Vector3 = -body.global_transform.basis.z
	direction.y = 0.0
	if direction.is_zero_approx():
		return GameCommandResult.rejected_temporary(
			&"simple_dodge_no_direction",
			"Dodge direction is empty."
		)
	body.move_and_collide(direction.normalized() * distance)
	return GameCommandResult.success_changed(&"simple_dodge_completed")

func is_valid() -> bool:
	return distance >= 0.0
```

Production dash должен перейти на отдельный movement/control adapter, если нужен duration, animation curve, temporary ownership или i-frames.

---

# 5. `game_place_mine_operation_simple.gd`

Mine создаётся через текущий `GameSpawnService`. `spawn()` возвращает `GameObjectHandle` в `GameCommandResult.payload`.

```gdscript
@tool
extends GameAbilityOperation
class_name GamePlaceMineOperationSimple

# ======== EXPORT =========
@export_file("*.tscn") var mine_scene_path: String = ""
@export_range(0.0, 10.0, 0.1) var forward_offset: float = 1.5
@export var burning_effect: GameEffectDefinition = null

# ====== PUBLIC ========
func execute(
	_abilities: GameAbilities,
	execution: GameAbilityExecution
) -> GameCommandResult:
	if execution == null or execution.get_request() == null:
		return GameCommandResult.configuration_error(
			&"simple_mine_execution_missing",
			"Place-mine execution is missing."
		)
	if mine_scene_path.is_empty():
		return GameCommandResult.configuration_error(
			&"simple_mine_scene_missing",
			"Mine scene path is empty."
		)

	var owner_handle: GameObjectHandle = execution.get_request().get_owner_handle()
	if owner_handle == null or not owner_handle.is_resolved():
		return GameCommandResult.invalid_target("Mine owner is unresolved.")
	var owner_root: Node3D = owner_handle.get_root() as Node3D
	var owner_context: GameObjectContext = owner_handle.get_context()
	if owner_root == null or owner_context == null:
		return GameCommandResult.invalid_target("Mine owner root/context is unavailable.")

	var spawn_service: GameSpawnService = owner_context.get_world_port(
		GameWorldPortIds.SPAWN_REQUEST
	) as GameSpawnService
	if spawn_service == null:
		return GameCommandResult.configuration_error(
			&"simple_spawn_service_missing",
			"Owner has no spawn world port."
		)

	var spawn_transform: Transform3D = owner_root.global_transform
	spawn_transform.origin += -owner_root.global_transform.basis.z.normalized() * forward_offset

	var spawn_result: GameCommandResult = spawn_service.spawn(
		mine_scene_path,
		spawn_transform,
		execution.get_execution_context()
	)
	if not spawn_result.is_success():
		return spawn_result

	var mine_handle: GameObjectHandle = spawn_result.get_payload() as GameObjectHandle
	if mine_handle == null or not mine_handle.is_resolved():
		return GameCommandResult.configuration_error(
			&"simple_spawn_payload_invalid",
			"Spawn service did not return a resolved GameObjectHandle."
		)
	var mine: GameMineSimple = mine_handle.get_root() as GameMineSimple
	if mine == null:
		return GameCommandResult.configuration_error(
			&"simple_spawned_mine_type_invalid",
			"Spawned root is not GameMineSimple."
		)

	mine.owner_handle = owner_handle
	mine.instigator_handle = owner_handle
	mine.targeting_service = owner_context.get_world_port(
		GameWorldPortIds.TARGETING_QUERY
	) as GameTargetingService
	mine.spawn_service = spawn_service
	mine.burning_effect = burning_effect
	mine.arm_after_delay()

	return GameCommandResult.success_changed(&"simple_mine_spawned", mine_handle)

func is_valid() -> bool:
	return not mine_scene_path.is_empty() and forward_offset >= 0.0
```

Текущий `GameSpawnService.spawn()` не inject-ит world ports в spawned kernel. Поэтому Mine получает нужные post-spawn services явно.

---

# 6. `game_monster_simple.gd`

AI state machine выражает attack через `GameMockAIControlSource.use_ability()`, а не через direct `GameAbilities.activate()`.

```gdscript
extends CharacterBody3D
class_name GameMonsterSimple

enum State { PATROL, CHASE, ATTACK, DEAD }

signal state_changed(state: State)
signal monster_died()

# ======== EXPORT =========
@export var kernel: GameObjectKernel = null
@export var control_arbiter: GameControlArbiter = null
@export var control_endpoint: GameControlEndpoint = null
@export var ai_control_source: GameMockAIControlSource = null
@export var abilities: GameAbilities = null
@export var effects: GameEffects = null
@export var death_policy: GameDeathPolicy = null
@export var navigation_agent: NavigationAgent3D = null
@export_range(0.1, 50.0, 0.1) var detect_distance: float = 10.0
@export_range(0.1, 50.0, 0.1) var lose_distance: float = 14.0
@export_range(0.1, 10.0, 0.1) var attack_distance: float = 1.8

# ======== PRIVATE VAR ======
var _state: State = State.PATROL
var _runtime_started: bool = false
var _target: Node3D = null
var _patrol_points: Array[Marker3D] = []
var _patrol_index: int = 0

# ======= OVERRIDE =======
func _physics_process(delta: float) -> void:
	if not _runtime_started:
		return
	_tick_ai()
	if abilities != null:
		abilities.advance_time(delta)
	if effects != null and kernel != null and kernel.get_object_context() != null:
		effects.advance_time(
			delta,
			kernel.get_object_context().create_root_execution_context(
				&"simple.monster.effects_tick",
				"Monster effects tick"
			)
		)
	if kernel != null:
		kernel.process_execution_queue()

# ====== PUBLIC ========
func start_runtime() -> void:
	if _runtime_started:
		return
	if kernel == null or kernel.get_object_context() == null:
		push_error("Monster kernel must be bound before start_runtime().")
		return
	var result: GameCommandResult = ai_control_source.attach(
		control_endpoint,
		control_arbiter
	)
	if not result.is_success():
		push_error(result.get_debug_message())
		return
	ai_control_source.request_control()
	if death_policy != null and not death_policy.died.is_connected(_on_died):
		death_policy.died.connect(_on_died)
	_runtime_started = true

func set_target(value: Node3D) -> void:
	_target = value

func set_patrol_points(value: Array[Marker3D]) -> void:
	_patrol_points = value.duplicate()
	_patrol_index = 0

# ====== HELPERS ========
func _tick_ai() -> void:
	if _state == State.DEAD or ai_control_source == null:
		return
	var distance: float = INF
	if _target != null:
		distance = global_position.distance_to(_target.global_position)

	match _state:
		State.PATROL:
			if _target != null and distance <= detect_distance:
				_set_state(State.CHASE)
				return
			_tick_patrol()
		State.CHASE:
			if _target == null or distance > lose_distance:
				_set_state(State.PATROL)
				return
			if distance <= attack_distance:
				_set_state(State.ATTACK)
				return
			_move_toward(_target.global_position)
		State.ATTACK:
			_stop_movement()
			if _target == null or distance > attack_distance:
				_set_state(State.CHASE)
				return
			_request_attack()

func _tick_patrol() -> void:
	if _patrol_points.is_empty():
		_stop_movement()
		return
	var marker: Marker3D = _patrol_points[_patrol_index]
	if marker == null:
		_advance_patrol()
		return
	if global_position.distance_to(marker.global_position) <= 0.6:
		_advance_patrol()
		return
	_move_toward(marker.global_position)

func _advance_patrol() -> void:
	if not _patrol_points.is_empty():
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()

func _move_toward(point: Vector3) -> void:
	if navigation_agent == null or kernel == null or kernel.get_object_context() == null:
		return
	navigation_agent.target_position = point
	var direction: Vector3 = navigation_agent.get_next_path_position() - global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		_stop_movement()
		return
	ai_control_source.move(
		direction.normalized(),
		1.0,
		kernel.get_object_context().create_root_execution_context(
			&"simple.monster.move",
			"Monster movement"
		)
	)

func _stop_movement() -> void:
	if ai_control_source == null or kernel == null or kernel.get_object_context() == null:
		return
	ai_control_source.stop(
		kernel.get_object_context().create_root_execution_context(
			&"simple.monster.stop",
			"Monster stop"
		)
	)

func _request_attack() -> void:
	if ai_control_source == null or kernel == null or kernel.get_object_context() == null:
		return
	ai_control_source.use_ability(
		&"simple.ability.monster.attack",
		[],
		kernel.get_object_context().create_root_execution_context(
			&"simple.monster.attack",
			"Monster attack"
		)
	)

func _set_state(value: State) -> void:
	if _state == value:
		return
	_state = value
	state_changed.emit(_state)

func _on_died(_execution_context: GameExecutionContext) -> void:
	if _state == State.DEAD:
		return
	_set_state(State.DEAD)
	_stop_movement()
	monster_died.emit()
```

Cooldown ability сам отклоняет частые attack intents; AI не обязан хранить отдельный attack timer.

---

# 7. `game_door_simple.gd`

```gdscript
extends AnimatableBody3D
class_name GameDoorSimple

signal door_opened()
signal door_closed()

@export var kernel: GameObjectKernel = null
@export var tags: GameTagContainer = null
@export var hinge: Node3D = null
@export_range(0.0, 170.0, 1.0) var open_angle_degrees: float = 95.0

var _is_open: bool = false
var _open_tag_handle: GameTagSourceHandle = null

func _ready() -> void:
	_refresh_visual()

func set_open_state(value: bool) -> GameCommandResult:
	if _is_open == value:
		return GameCommandResult.success_unchanged(
			&"door_already_open" if value else &"door_already_closed"
		)
	if tags == null:
		return GameCommandResult.configuration_error(
			&"door_tags_missing",
			"Door requires GameTagContainer."
		)

	if value:
		_open_tag_handle = tags.add_tag(&"state.open", &"simple.door.state")
		if _open_tag_handle == null:
			return GameCommandResult.configuration_error(
				&"door_open_tag_rejected",
				"GameTagContainer rejected state.open. Configure the tag catalog."
			)
	else:
		if _open_tag_handle != null:
			tags.remove_tag(_open_tag_handle)
		_open_tag_handle = null

	_is_open = value
	_refresh_visual()
	if _is_open:
		door_opened.emit()
		return GameCommandResult.success_changed(&"door_opened")
	door_closed.emit()
	return GameCommandResult.success_changed(&"door_closed")

func _refresh_visual() -> void:
	if hinge != null:
		hinge.rotation_degrees.y = open_angle_degrees if _is_open else 0.0
```

Door no longer rebuilds offers.

---

# 8. `game_door_set_open_operation_simple.gd`

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
			"Door ability execution is missing."
		)
	var owner_handle: GameObjectHandle = execution.get_request().get_owner_handle()
	if owner_handle == null or not owner_handle.is_resolved():
		return GameCommandResult.invalid_target("Door owner is unresolved.")
	var door: GameDoorSimple = owner_handle.get_root() as GameDoorSimple
	if door == null:
		return GameCommandResult.invalid_target("Door ability owner is not GameDoorSimple.")
	return door.set_open_state(open)
```

Door abilities:

```text
open  blocked_owner_tags  = [state.open]
close required_owner_tags = [state.open]
```

`GameInteractionTarget.reactions` map semantic `open/close` to these abilities. Source code never calls `door.open()`/`door.close()`.

---

# 9. `game_barrel_simple.gd`

```gdscript
extends StaticBody3D
class_name GameBarrelSimple

signal barrel_exploded(affected_count: int)

@export var kernel: GameObjectKernel = null
@export var death_policy: GameDeathPolicy = null
@export_range(0.1, 20.0, 0.1) var explosion_radius: float = 3.5
@export_range(0.0, 10000.0, 0.1) var explosion_damage: float = 45.0

var _exploded: bool = false

func _ready() -> void:
	if death_policy != null and not death_policy.died.is_connected(_on_died):
		death_policy.died.connect(_on_died)

func explode(execution_context: GameExecutionContext = null) -> void:
	if _exploded:
		return
	_exploded = true
	if kernel == null or kernel.get_object_context() == null:
		barrel_exploded.emit(0)
		return

	var context: GameObjectContext = kernel.get_object_context()
	var barrel_handle: GameObjectHandle = context.get_object_handle()
	var causal_context: GameExecutionContext = execution_context
	if causal_context == null:
		causal_context = context.create_root_execution_context(
			&"simple.barrel.explosion",
			"Barrel explosion"
		)
	var targeting_service: GameTargetingService = context.get_world_port(
		GameWorldPortIds.TARGETING_QUERY
	) as GameTargetingService
	var affected_count: int = _apply_radial_damage(
		targeting_service,
		barrel_handle,
		barrel_handle,
		causal_context
	)
	barrel_exploded.emit(affected_count)

	var spawn_service: GameSpawnService = context.get_world_port(
		GameWorldPortIds.DESPAWN_REQUEST
	) as GameSpawnService
	if spawn_service != null:
		spawn_service.despawn(barrel_handle, &"barrel_exploded", true)
	else:
		queue_free()

func _apply_radial_damage(
	targeting_service: GameTargetingService,
	source_handle: GameObjectHandle,
	instigator_handle: GameObjectHandle,
	execution_context: GameExecutionContext
) -> int:
	if targeting_service == null:
		return 0
	var query: Dictionary = targeting_service.query_sphere(
		global_position,
		explosion_radius,
		GameCapabilityIds.DAMAGE_RECEIVER,
		[],
		[source_handle.get_stable_id()]
	)
	var affected_count: int = 0
	for value: Variant in query.get("handles", []):
		var target_handle: GameObjectHandle = value as GameObjectHandle
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
			explosion_damage,
			[&"damage.explosion"],
			execution_context
		)
		if receiver.apply_damage(request).is_success():
			affected_count += 1
	return affected_count

func _on_died(execution_context: GameExecutionContext) -> void:
	explode(execution_context)
```

---

# 10. `game_mine_simple.gd`

```gdscript
extends StaticBody3D
class_name GameMineSimple

enum State { PLACED, ARMED, EXPLODED }

signal mine_armed()
signal mine_exploded(affected_count: int)

# ======== EXPORT =========
@export var kernel: GameObjectKernel = null
@export var death_policy: GameDeathPolicy = null
@export var trigger_area: Area3D = null
@export var trigger_collision: CollisionShape3D = null
@export_range(0.0, 5.0, 0.01) var arming_delay: float = 0.35
@export_range(0.1, 20.0, 0.1) var explosion_radius: float = 3.0
@export_range(0.0, 10000.0, 0.1) var explosion_damage: float = 50.0

# ======== RUNTIME INJECTION =========
var owner_handle: GameObjectHandle = null
var instigator_handle: GameObjectHandle = null
var targeting_service: GameTargetingService = null
var spawn_service: GameSpawnService = null
var burning_effect: GameEffectDefinition = null

# ======== PRIVATE VAR ======
var _state: State = State.PLACED

# ======= OVERRIDE =======
func _ready() -> void:
	if trigger_collision != null:
		trigger_collision.set_deferred("disabled", true)
	if trigger_area != null and not trigger_area.body_entered.is_connected(_on_body_entered):
		trigger_area.body_entered.connect(_on_body_entered)
	if death_policy != null and not death_policy.died.is_connected(_on_died):
		death_policy.died.connect(_on_died)

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

func explode(
	trigger_instigator: GameObjectHandle = null,
	execution_context: GameExecutionContext = null
) -> void:
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
	var causal_context: GameExecutionContext = execution_context
	if causal_context == null:
		causal_context = context.create_root_execution_context(
			&"simple.mine.explosion",
			"Mine explosion"
		)

	var affected_count: int = _apply_explosion(
		mine_handle,
		effective_instigator,
		causal_context
	)
	mine_exploded.emit(affected_count)

	if spawn_service != null:
		spawn_service.despawn(mine_handle, &"mine_exploded", true)
	else:
		queue_free()

# ====== HELPERS ========
func _on_body_entered(body: Node3D) -> void:
	if _state != State.ARMED or body == null:
		return
	var body_kernel: GameObjectKernel = body.get("kernel") as GameObjectKernel
	if body_kernel == null or body_kernel.get_object_context() == null:
		return
	var body_handle: GameObjectHandle = body_kernel.get_object_context().get_object_handle()
	if body_handle == null or not body_handle.is_resolved():
		return
	if owner_handle != null and body_handle.get_stable_id() == owner_handle.get_stable_id():
		return
	explode(body_handle)

func _on_died(execution_context: GameExecutionContext) -> void:
	explode(instigator_handle, execution_context)

func _apply_explosion(
	mine_handle: GameObjectHandle,
	effective_instigator: GameObjectHandle,
	execution_context: GameExecutionContext
) -> int:
	if targeting_service == null:
		return 0
	var excluded_ids: Array[StringName] = [mine_handle.get_stable_id()]
	if owner_handle != null:
		excluded_ids.append(owner_handle.get_stable_id())
	var query: Dictionary = targeting_service.query_sphere(
		global_position,
		explosion_radius,
		GameCapabilityIds.DAMAGE_RECEIVER,
		[],
		excluded_ids
	)
	var affected_count: int = 0

	for value: Variant in query.get("handles", []):
		var target_handle: GameObjectHandle = value as GameObjectHandle
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
			mine_handle,
			effective_instigator,
			target_handle,
			explosion_damage,
			[&"damage.explosion"],
			execution_context
		)
		if not receiver.apply_damage(damage_request).is_success():
			continue
		affected_count += 1

		if burning_effect != null:
			var target_effects: GameEffects = target_context.get_capability(
				GameCapabilityIds.EFFECTS_RECEIVER
			) as GameEffects
			if target_effects != null:
				target_effects.apply_effect(
					burning_effect,
					mine_handle,
					effective_instigator,
					execution_context
				)

	return affected_count
```

`burning_effect.meter_operations` в текущем API модифицирует meter напрямую на каждом period. Это не `GameDamageRequest`.

---

# 11. Interaction wiring

Player `interact` button должен быть обычным `GameAbilityInputBinding`:

```text
interact → slot.interaction
```

`slot.interaction` ссылается на grant `simple.ability.player.interact`, definition которого содержит `GameInteractionAbilityOperation`.

Door target:

```text
GameAbilities.initial_abilities
├── simple.ability.door.open
└── simple.ability.door.close

GameInteractionTarget.reactions
├── intent=open  → simple.ability.door.open
└── intent=close → simple.ability.door.close
```

Перед нажатием `E` sensing layer должен установить focus через `GameInteractionSource.set_focus()`; core не выбирает spatial target автоматически.

---

# 12. Что проверить в Inspector

## Все static world objects

```text
GameObjectKernel.auto_initialize = false
```

## Player

```text
GameAbilities.initial_abilities = attack, dodge, place_mine, interact
GameAbilityLoadout.initial_slots = primary, mobility, utility_1, interaction
GamePlayerInputSource.ability_input_bindings = InputAction → slot
```

## Monster

```text
GameAbilities.initial_abilities = simple.ability.monster.attack
GameMockAIControlSource attached after world bind
```

## Door

```text
GameTagContainer knows state.open
GameAbilities.initial_abilities = door.open, door.close
GameInteractionTarget.reactions = open, close
```

## Mine

Mine scene должна иметь direct-child `GameObjectKernel`, потому что `GameSpawnService.spawn()` ищет kernel среди direct children root.

## Burning

```text
duration_policy = DURATION
duration = 4
period = 1
granted_tags = [status.burning]
meter_operations = [{meter_id: simple.meter.health, delta: -5}]
```

---

# 13. API paths, которые этот companion намеренно не использует

Не используйте в этом примере:

```text
Player._unhandled_input() → concrete ability IDs
GameAbilities.activate() напрямую из player input glue
activation_payload.actor_node
activation_payload.targeting_service
activation_payload.dodge_callable
activation_payload.spawn_mine_callable
manual object_resolver.register_handle() после GameWorldContext.bind_kernel()
неопределённый unregister API
GameInteractionOffer.command_id
GameInteractionOffer.ability_id
Door-specific command dispatcher
```

Это либо обходит текущий control/loadout/world contract, либо уже удалено из публичного API.

---

# 14. Локальный scheduler

Локальные вызовы:

```text
abilities.advance_time(delta)
effects.advance_time(delta, execution_context)
kernel.process_execution_queue()
```

оставлены намеренно. Текущий GCA не требует единого глобального scheduler; owner/subscene может контролировать advancement самостоятельно.

---

# 15. Ограничения tutorial

- Spatial interaction sensing/focus остаётся project-level adapter.
- Simple dodge — одношаговый fallback, не production timed dash.
- Текущий `GameSpawnService.spawn()` не inject-ит world ports в spawned kernel; Mine получает нужные post-spawn services явно.
- Current periodic Effects меняют meters через `meter_operations`; combat-aware DoT через `GameDamageReceiver` требует отдельного gameplay adapter.
- Presentation/VFX/SFX остаются отдельным слоем.

Tutorial не создаёт `project.godot`, `.tscn`, `.tres`, `.uid` или бинарные assets: сцены и Resources собираются вручную по текущим public contracts.
