# GCA Stage 1 Foundation — практическое руководство по API

## 1. Ментальная модель

Каждый игровой объект состоит из обычного корня Godot и одного дочернего `GameObjectKernel`. Все gameplay-компоненты являются прямыми дочерними `GameFeature` у kernel.

```text
ObjectRoot
└── GameObjectKernel
    ├── GameObjectIdentity
    ├── GameTagContainer
    └── GameMyFeature
```

Внешний код обращается к объекту через `GameObjectHandle`, команды и запросы. Feature-компонент обращается к инфраструктуре через `GameObjectContext`. Sibling-feature не ищется через `get_parent()` или `get_node()`.

---

## 2. GameObjectKernel — главный публичный API объекта

### Жизненный цикл

- `initialize_kernel() -> GameCommandResult` — вручную собрать и активировать объект. Обычно не нужен при `auto_initialize = true`.
- `deactivate_kernel(reason)` — остановить gameplay-команды, сохранив читаемое состояние.
- `reactivate_kernel() -> GameCommandResult` — повторно активировать объект.
- `shutdown_kernel()` — окончательно завершить объект и инвалидировать handle.

### Обращение к объекту

- `get_object_handle() -> GameObjectHandle` — безопасная ссылка на объект.
- `get_object_context() -> GameObjectContext` — локальный API kernel для feature/служебного кода.
- `dispatch_command(command) -> GameCommandResult` — отправить изменение состояния.
- `dispatch_query(query) -> GameQueryResult` — прочитать состояние без мутации.

### Execution chain

- `create_root_execution_context(cause_type, debug_label)` — начать новую причинно-следственную цепочку.
- `create_child_execution_context(parent, cause_type, debug_label)` — продолжить существующую цепочку.
- `process_execution_queue(max_operations = -1)` — выполнить отложенные операции.

Текущая Stage 1 не обрабатывает очередь автоматически. После enqueue нужен вызов `process_execution_queue()` со стороны владельца или будущего scheduler host.

### Динамическая композиция

- `register_runtime_feature(feature)` — зарегистрировать уже добавленный прямой дочерний feature.
- `remove_runtime_feature(feature)` — безопасно снять runtime feature.

`GameObjectIdentity` и `GameTagContainer` после активации динамически менять нельзя.

### Диагностика

- `get_lifecycle_state()`
- `get_feature(feature_id)`
- `get_features()`
- `get_diagnostics()`
- `get_configuration_errors()`
- `get_debug_snapshot()`

---

## 3. GameFeature — что переопределять в новом компоненте

### Метаданные

В `_init()` обычно задаются:

- `feature_id`;
- `provided_capabilities`;
- `required_dependencies`;
- `optional_dependencies`.

### Lifecycle callbacks

- `on_game_initialize() -> GameCommandResult` — получить зависимости, создать runtime-state.
- `on_game_activate() -> GameCommandResult` — включить подписки или gameplay-готовность.
- `on_game_deactivate(reason)` — временно остановиться.
- `on_game_shutdown()` — очистить handles, ссылки и runtime-state.
- `on_capability_lost(capability_id)` — отреагировать на удаление поставщика.

Не вызывайте `discover_feature()`, `resolve_dependencies()`, `initialize_feature()` и подобные lifecycle-методы вручную: ими управляет kernel.

### Commands

- `can_handle_command(command_type_id) -> bool`
- `handle_command(command) -> GameCommandResult`

### Queries

- `can_handle_query(query_type_id) -> bool`
- `handle_query(query) -> GameQueryResult`

### Events

- `on_local_event(event)` — получить локальный факт от kernel.
- `publish_local_event(event) -> bool` — отправить факт вверх в kernel.

### Методы, которыми feature пользуется внутри

- `get_context() -> GameObjectContext`
- `get_dependency(capability_id) -> Variant`
- `has_cached_dependency(capability_id)`
- `request_runtime_removal()`

---

## 4. GameObjectContext — основной рабочий фасад feature

### Свой объект

- `get_object_root()` — корневой Node объекта; использовать для собственного physics/presentation, не для поиска sibling-feature.
- `get_object_handle()`
- `get_identity()`
- `get_kernel()`

### Capabilities

- `get_capability(id)` — один exclusive provider.
- `get_capabilities(id)` — все multi providers.

Для объявленной зависимости лучше один раз вызвать `get_dependency()` в `on_game_initialize()` и сохранить типизированную ссылку в приватное поле.

### Tags

- `has_exact_tag(tag_id)`
- `has_tag_or_child(parent_tag_id)`

### Commands и queries

- `dispatch_command(command)`
- `dispatch_query(query)`

### Operations

- `enqueue_operation(operation)`
- `process_operations(max_operations = -1)`
- `cancel_root_operations(root_operation_id, reason)`
- `create_root_execution_context(...)`
- `create_child_execution_context(...)`

### Сервисы и диагностика

- `get_world_port(port_id)` — Stage 1 injection point; полноценные world services появятся позднее.
- `get_diagnostics()`
- `has_runtime_flag(flag_id)`

---

## 5. Типовой GameFeature

```gdscript
extends GameFeature
class_name GameDoorStateFeature

# ======= CONSTS =========
const CAPABILITY_DOOR_STATE: StringName = &"door.state"
const COMMAND_OPEN: StringName = &"door.open"
const QUERY_IS_OPEN: StringName = &"door.is_open"
const EVENT_OPENED: StringName = &"door.opened"

# ======== PRIVATE VAR ======
var _is_open: bool = false

# ======= OVERRIDE =======
func _init() -> void:
    feature_id = &"door.state"

    var spec := GameCapabilitySpec.new()
    spec.capability_id = CAPABILITY_DOOR_STATE
    spec.cardinality = GameCapabilityCardinality.Type.EXCLUSIVE
    provided_capabilities = [spec]

# ====== PUBLIC ========
func can_handle_command(command_type_id: StringName) -> bool:
    return command_type_id == COMMAND_OPEN

func handle_command(command: GameCommand) -> GameCommandResult:
    if _is_open:
        return GameCommandResult.success_unchanged(&"door_already_open")

    _is_open = true
    publish_local_event(GameLocalEvent.new(
        EVENT_OPENED,
        get_context().get_object_handle(),
        command.get_execution_context(),
        {"is_open": true}
    ))
    return GameCommandResult.success_changed(&"door_opened")

func can_handle_query(query_type_id: StringName) -> bool:
    return query_type_id == QUERY_IS_OPEN

func handle_query(_query: GameQuery) -> GameQueryResult:
    return GameQueryResult.found_value(_is_open)
```

---

## 6. Отправка команды

```gdscript
var target_handle: GameObjectHandle = door_kernel.get_object_handle()
var execution_context: GameExecutionContext = source_kernel.create_root_execution_context(
    &"interaction.open_door",
    "Open door"
)

var command := GameCommand.new(
    GameDoorStateFeature.COMMAND_OPEN,
    source_kernel.get_object_handle(),
    target_handle,
    execution_context,
    null,
    GameDoorStateFeature.CAPABILITY_DOOR_STATE
)

var result: GameCommandResult = source_kernel.dispatch_command(command)
if not result.is_success():
    push_warning("Door command failed: %s" % result.get_reason_code())
```

Всегда рекомендуется указывать `required_capability_id`: kernel сразу сузит маршрутизацию до нужного поставщика.

---

## 7. Выполнение query

```gdscript
var query := GameQuery.new(
    GameDoorStateFeature.QUERY_IS_OPEN,
    source_kernel.get_object_handle(),
    door_kernel.get_object_handle(),
    GameDoorStateFeature.CAPABILITY_DOOR_STATE
)

var result: GameQueryResult = source_kernel.dispatch_query(query)
if result.is_found():
    var is_open: bool = bool(result.get_value())
```

Query не должна изменять состояние, добавлять tags или публиковать gameplay-события.

---

## 8. Объявление и получение зависимости

```gdscript
extends GameFeature
class_name GameDoorIndicatorFeature

var _door_state: GameDoorStateFeature = null

func _init() -> void:
    feature_id = &"door.indicator"

    var dependency := GameCapabilityDependency.new()
    dependency.capability_id = GameDoorStateFeature.CAPABILITY_DOOR_STATE
    dependency.required = true
    dependency.expected_cardinality = GameCapabilityCardinality.Type.EXCLUSIVE
    dependency.expected_contract = load("res://content/gameplay/doors/game_door_state_feature.gd")
    dependency.loss_policy = GameCapabilityLossPolicy.Type.DEACTIVATE_FEATURE
    required_dependencies = [dependency]

func on_game_initialize() -> GameCommandResult:
    _door_state = get_dependency(GameDoorStateFeature.CAPABILITY_DOOR_STATE) as GameDoorStateFeature
    if _door_state == null:
        return GameCommandResult.configuration_error(
            &"missing_door_state",
            "Door indicator requires door.state"
        )
    return GameCommandResult.success_changed(&"door_indicator_initialized")
```

Зависимость кешируется. Не вызывайте `get_capability()` каждый кадр.

---

## 9. Tags

### Добавление

```gdscript
var tags := get_context().get_capability(GameCapabilityIds.TAGS_MODIFY) as GameTagContainer
var burning_handle: GameTagSourceHandle = tags.add_tag(
    GameTagIds.STATUS_BURNING,
    &"effect.burning"
)
```

### Снятие

```gdscript
tags.remove_tag(burning_handle)
```

Храните возвращённый handle у владельца тега. Не снимайте тег по имени: несколько источников могут одновременно выдавать один tag.

### Проверка

```gdscript
if get_context().has_exact_tag(GameTagIds.STATUS_BURNING):
    pass

if get_context().has_tag_or_child(&"status"):
    pass
```

---

## 10. Отложенные операции

```gdscript
func _queue_followup(parent_context: GameExecutionContext) -> GameCommandResult:
    var child_context := get_context().create_child_execution_context(
        parent_context,
        &"door.followup",
        "Door follow-up"
    )

    var operation := GameCallbackOperation.new(
        &"door.followup",
        child_context,
        _execute_followup,
        &"door.open",
        get_context().get_object_handle(),
        &"after_open",
        "Door follow-up"
    )

    return get_context().enqueue_operation(operation)

func _execute_followup(_context: GameExecutionContext) -> GameCommandResult:
    return GameCommandResult.success_changed(&"followup_completed")
```

После enqueue текущая версия требует вызова:

```gdscript
kernel.process_execution_queue()
```

Не вызывайте дочернюю операцию рекурсивно напрямую.

---

## 11. GameObjectHandle

Основные методы:

- `is_resolved()` — объект ещё загружен и kernel доступен;
- `is_invalidated()` — объект окончательно инвалидирован текущим runtime;
- `get_stable_id()`;
- `get_root()`;
- `get_kernel()`;
- `get_context()`.

Перед межобъектным обращением проверяйте `is_resolved()`. Не храните постоянную strong-ссылку на чужой Node там, где нужен handle.

---

## 12. Result handling

### GameCommandResult

Главный метод — `is_success()`. Для причины используйте:

- `get_status()`;
- `get_reason_code()`;
- `get_debug_message()`;
- `get_payload()`;
- `get_source_operation_id()`.

Успех с изменением и без изменения различаются: `SUCCESS_CHANGED` и `SUCCESS_UNCHANGED`.

### GameQueryResult

- `is_found()`;
- `is_failure()`;
- `get_status()`;
- `get_reason_code()`;
- `get_value()`.

`NOT_FOUND` — корректное отсутствие значения, а не обязательно ошибка.

---

## 13. Что не надо вызывать напрямую

Следующие методы являются инфраструктурными и обычно вызываются только kernel:

- `discover_feature()`;
- `mark_registered()`;
- `resolve_dependencies()`;
- `initialize_feature()`;
- `activate_feature()`;
- `deactivate_feature()`;
- `shutdown_feature()`;
- методы `GameCapabilityRegistry.register_provider()` и `unregister_provider()`.

Также не следует в gameplay-коде обращаться к sibling-feature через `get_parent()`, `get_node()` или прямое поле NodePath.

---

## 14. Практический порядок работы

1. Создать корень подходящего типа Godot.
2. Добавить один `GameObjectKernel`.
3. Добавить прямыми детьми kernel `GameObjectIdentity`, `GameTagContainer` и gameplay-features.
4. Назначить уникальный `stable_id`.
5. В каждом feature объявить ID, capabilities и dependencies.
6. В `on_game_initialize()` получить и кешировать зависимости.
7. Для изменения состояния использовать commands.
8. Для чтения использовать queries.
9. Для произошедших фактов использовать local events.
10. Для цепочек и отложенной работы использовать execution context + queue.
11. Для временного состояния использовать tags с source handles; позднее — effects, а не динамические Nodes.
12. При ошибке смотреть `get_debug_snapshot()` и `GameDebugPanel`.

---

## 15. Ограничения текущей Stage 1

- Handle разрешает только загруженный локальный объект; world resolver будет в Stage 5.
- Local event распространяется только внутри одного kernel.
- Очередь операций требует явного processing host.
- Attributes, meters, effects, damage и abilities пока отсутствуют.
- `strict_validation = true` блокирует активацию при editor/configuration warning.
- Queries доступны для деактивированного объекта, commands временно отклоняются.
