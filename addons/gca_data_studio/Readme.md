# GCA Data Studio

`GCA Data Studio` — editor-only инструмент для работы с data-driven definitions GCA в Godot Engine 4.6.

Он не заменяет Godot `Resource` и `EditorInspector`: таблица предназначена для быстрого обзора и редактирования простых полей, а полный Inspector остаётся источником для вложенных Resources, requirements, costs, operations и Dictionary-структур.

## Поддерживаемые creation schemas

Data Studio умеет создавать четыре текущих definition-типа:

```text
GameAttributeDefinition
GameMeterDefinition
GameEffectDefinition
GameAbilityDefinition
```

Категории этих типов показываются даже в пустом проекте. Поэтому новый проект может создать первый Attribute/Meter/Effect/Ability без предварительно существующего `.tres`.

Другие `Game*` Resources со стабильным ID могут индексироваться и отображаться через общий список, но отдельная creation schema для них не обещается.

## Индексирование

По умолчанию сканируется:

```text
res://content
```

Поддерживаемые fallback ID-поля:

```text
tag_id
attribute_id
meter_id
effect_id
ability_id
offer_id
cue_id
spawn_id
archetype_id
definition_id
id
```

Data Studio не создаёт собственную БД и не копирует gameplay data: редактируются обычные `.tres`/`.res` Resources.

## Текущие таблицы

### Attributes — `GameAttributeDefinition`

Inline-поля соответствуют текущему API:

```text
attribute_id
display_name
default_base
clamp_policy
minimum
maximum
display_precision
save_base
category_tags
```

`debug_description` доступен через Inspector.

### Meters — `GameMeterDefinition`

```text
meter_id
initial_policy
initial_value
maximum_policy
constant_maximum
maximum_attribute_id
minimum
maximum_change_policy
depletion_threshold
save_current
```

При `maximum_policy == ATTRIBUTE` validator проверяет существование `maximum_attribute_id` среди индексированных Attributes.

### Effects — `GameEffectDefinition`

```text
effect_id
duration_policy
duration
period
execute_period_on_apply
stacking_policy
stack_limit
required_target_tags
blocked_target_tags
granted_tags
persistent
```

Через Inspector редактируются:

```text
attribute_modifiers: Array[Dictionary]
meter_operations: Array[Dictionary]
debug_description
```

Важно: текущий `GameEffects.advance_time()` повторно применяет `meter_operations` напрямую к `GameMeters`. Периодический Effect сам по себе не создаёт `GameDamageRequest`.

### Abilities — `GameAbilityDefinition`

Таблица показывает актуальные простые поля:

```text
ability_id
display_name
ability_tags
required_owner_capabilities
required_owner_tags
blocked_owner_tags
granted_tags_during_execution
passive
cooldown_duration
cooldown_key
cooldown_groups
occupied_channels
conflict_policy
retrigger_policy
persist_grant
persist_cooldown
save_execution_policy
schema_version
```

Через Inspector редактируются:

```text
debug_description
requirements: Array[GameAbilityRequirement]
costs: Array[GameAbilityCost]
operations: Array[GameAbilityOperation]
```

## Создание definition

1. Включить plugin в `Project Settings → Plugins`.
2. Открыть вкладку `GCA Data Studio`.
3. Выбрать `Attributes`, `Meters`, `Effects` или `Abilities`.
4. Нажать `Create`.
5. Отредактировать stable ID и остальные поля.

Стандартные каталоги:

```text
res://content/gameplay/attributes
res://content/gameplay/meters
res://content/gameplay/effects
res://content/gameplay/abilities
```

Префиксы:

```text
attr_*.tres
meter_*.tres
effect_*.tres
ability_*.tres
```

Stable ID и имя файла — разные контракты.

## Inline editing и Inspector

Inline поддерживаются:

- `String` / `StringName`;
- `int` / `float`;
- `bool`;
- enum;
- `Array[StringName]` как список через запятую.

Сложные значения редактируйте стандартным Inspector. Это намеренная граница инструмента: Data Studio не должен дублировать всю систему редактирования Resources Godot.

## Validation

`Validate` проверяет индекс и вызывает type-specific проверки, включая:

- пустой stable ID;
- duplicate ID внутри одного Resource class;
- `definition.is_valid()`;
- Meter reference на отсутствующий Attribute;
- некорректный constant maximum;
- Effect duration/period;
- Effect modifier на отсутствующий Attribute;
- Effect meter operation на отсутствующий Meter;
- active Ability без operations;
- отрицательный cooldown;
- пустые capability/channel/StringName IDs.

Validator не изменяет gameplay data.

## Архитектура

```text
addons/gca_data_studio/
├── plugin.cfg
├── game_data_studio_plugin.gd
├── Readme.md
├── core/
│   ├── game_data_schema_registry.gd
│   ├── game_data_index.gd
│   └── game_data_validator.gd
└── ui/
    ├── ui_gca_data_studio.tscn
    └── game_data_studio_dock.gd
```

`GameDataSchemaRegistry` задаёт creation schemas и table columns. `GameDataIndex` индексирует Resources и всегда возвращает явно поддерживаемые creation categories, даже если соответствующих файлов пока нет. `GameDataValidator` проверяет ссылки и type-specific invariants. `GameDataStudioDock` использует стандартный `EditorInspector` для полного редактирования.

## Ограничения

В текущем scope нет:

- отдельного tag picker/catalog UI;
- вложенных таблиц requirements/costs/operations;
- reverse-reference graph;
- безопасного rename-ID workflow;
- runtime monitor;
- отдельной creation schema для `GameInteractionReaction`, loadout slot resources и world integrations.

Это не означает, что эти runtime APIs отсутствуют: они просто редактируются стандартным Godot Inspector, пока для них не добавлен специализированный Data Studio workflow.
