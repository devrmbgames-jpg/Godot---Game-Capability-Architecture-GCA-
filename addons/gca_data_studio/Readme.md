# GCA Data Studio

`GCA Data Studio` — editor-only плагин для табличной работы с data-driven определениями Game Capability Architecture в Godot Engine 4.6.

Плагин не заменяет Godot `Resource`, SceneTree или Inspector. Он индексирует обычные `.tres`/`.res` определения, показывает их в едином интерфейсе, позволяет быстро изменять простые поля, создавать новые определения и выполнять проектную валидацию.

## Текущая версия

Версия `0.1.0` реализует первый рабочий слой:

- отдельный main-screen редактора `GCA Data Studio`;
- рекурсивное индексирование GCA Resources из `res://content`;
- таблицы Attributes, Meters, Effects и Abilities;
- общий список всех индексируемых определений;
- поддержка дополнительных `Game*` Resources со стабильным ID;
- поиск по ID, имени, типу и пути;
- inline-редактирование строк, чисел, bool, enum и массивов `StringName`;
- просмотр выбранного ресурса через стандартный `EditorInspector`;
- создание новых definition Resources;
- сохранение через `ResourceSaver`;
- интеграция изменений с `EditorUndoRedoManager`;
- проверка duplicate ID и вызов `definition.is_valid()`;
- проверка Meter → Attribute;
- проверка Effect modifier → Attribute;
- проверка Effect meter operation → Meter;
- базовая проверка Ability definitions.

## Установка

1. Скопировать каталог:

```text
addons/gca_data_studio/
```

в корень Godot-проекта.

2. Открыть:

```text
Project → Project Settings → Plugins
```

3. Включить `GCA Data Studio`.

4. В верхней панели редактора появится вкладка:

```text
GCA Data Studio
```

Репозиторий GCA намеренно не содержит `project.godot`, сцен, `.tres`, `.uid` и бинарных ресурсов. Плагин необходимо перенести в целевой проект Godot 4.6 и включить там вручную.

## Интерфейс

```text
┌───────────────────────────────────────────────────────────────────┐
│ GCA Data Studio | Search | Refresh | Validate | Create           │
├───────────────┬──────────────────────────┬────────────────────────┤
│ Categories    │ Definition Table         │ Godot Inspector        │
├───────────────┴──────────────────────────┴────────────────────────┤
│ Status                                                            │
└───────────────────────────────────────────────────────────────────┘
```

Слева выбирается тип данных, в центре отображается таблица, справа — стандартный Inspector выбранного Resource.

## Индексирование

По умолчанию сканируется:

```text
res://content
```

Индексируются:

- `GameAttributeDefinition`;
- `GameMeterDefinition`;
- `GameEffectDefinition`;
- `GameAbilityDefinition`;
- другие `Game*` Resources, если у них есть стабильное ID-поле.

Поддерживаемые резервные ID-поля:

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

Сырые текстуры, модели, материалы и другие Resources без GCA ID в таблицу не попадают.

## Таблицы

### Attributes

Источник:

```text
GameAttributeDefinition
```

Основные колонки:

- `attribute_id`;
- `display_name`;
- `default_base`;
- `clamp_policy`;
- `minimum`;
- `maximum`;
- `save_base`;
- `category_tags`.

### Meters

Источник:

```text
GameMeterDefinition
```

При `maximum_policy == ATTRIBUTE` валидатор проверяет, что `maximum_attribute_id` существует среди индексированных Attributes.

### Effects

Источник:

```text
GameEffectDefinition
```

В таблице доступны duration, period, stacking, granted tags и persistence.

Текущие вложенные структуры:

```text
attribute_modifiers: Array[Dictionary]
meter_operations: Array[Dictionary]
```

редактируются через Inspector. Data Studio проверяет их целевые Attribute и Meter IDs.

### Abilities

Источник:

```text
GameAbilityDefinition
```

В таблице доступны:

- stable ID;
- display name;
- passive state;
- cooldown;
- cooldown key;
- occupied channels;
- conflict policy;
- persistence flags;
- schema version.

Requirements, costs и operations остаются обычными вложенными Resources и редактируются через Inspector.

## Создание Definition

1. Выбрать категорию Attributes, Meters, Effects или Abilities.
2. Нажать `Create`.
3. Плагин создаст новый Resource в стандартном каталоге категории.
4. Отредактировать stable ID и остальные поля в таблице или Inspector.

Примеры автоматически используемых каталогов:

```text
res://content/gameplay/attributes
res://content/gameplay/meters
res://content/gameplay/effects
res://content/gameplay/abilities
```

Префиксы файлов:

```text
attr_*.tres
meter_*.tres
effect_*.tres
ability_*.tres
```

Stable ID и путь файла являются разными контрактами. Переименование файла не должно неявно менять ID.

Новая active ability может сразу получить validation error, потому что `GameAbilityDefinition.is_valid()` требует хотя бы одну operation. Это ожидаемо: добавьте operations через Inspector.

## Inline-редактирование

Поддерживаются:

- `String` и `StringName`;
- `int`;
- `float`;
- `bool`;
- enum;
- массивы строковых ID через значения, разделённые запятыми.

Изменения применяются к исходному Resource и сохраняются. Undo/Redo проходит через `EditorUndoRedoManager`.

Сложные значения следует редактировать через Inspector:

- вложенные Resources;
- массивы Resources;
- Dictionary-поля Effects;
- PackedScene;
- custom policies;
- ссылки на узлы внутри сцены.

Data Studio не хранит вторую копию данных и не создаёт собственную базу.

## Validation

Кнопка `Validate` проверяет весь индекс.

Текущие проверки:

- пустой stable ID;
- duplicate ID внутри одного Resource class;
- неуспешный `definition.is_valid()`;
- несоответствие префикса файла;
- Meter с отсутствующим maximum Attribute;
- constant maximum ниже minimum;
- некорректная Effect duration или period;
- Effect modifier без Attribute;
- Effect modifier с неизвестным Attribute;
- Effect meter operation без Meter;
- Effect meter operation с неизвестным Meter;
- active Ability без operations;
- отрицательный Ability cooldown;
- пустой capability или channel ID;
- пустые `StringName` в массивах.

Результат отображается в колонке `Status` и в нижней строке состояния. Подробности ошибок доступны через tooltip статуса строки.

## Архитектура плагина

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
    └── game_data_studio_dock.gd
```

### GameDataSchemaRegistry

Описывает:

- поддерживаемые definition classes;
- ID и display properties;
- таблицы и типы ячеек;
- каталоги создания;
- правила имён файлов.

Новые типы данных добавляются через новую schema entry, а не через hardcoded ветвления UI.

### GameDataIndex

Отвечает за:

- обход каталогов;
- загрузку `.tres`/`.res`;
- определение класса и stable ID;
- сортировку;
- быстрый поиск по пути и типу;
- хранение validation issues.

### GameDataValidator

Выполняет common и type-specific проверки. Валидатор не изменяет данные.

### GameDataStudioDock

Строит main-screen интерфейс и связывает таблицу, Inspector, индекс, валидатор, создание и Undo/Redo.

## Архитектурные ограничения

Плагин:

- editor-only;
- не импортируется из `content/core`;
- не используется runtime-кодом;
- не заменяет SceneTree или Inspector;
- не создаёт скрытые gameplay-компоненты;
- не хранит runtime handles как persistent IDs;
- не изменяет shared definitions во время игры;
- не редактирует NodePath-ссылки между узлами сцены через таблицу;
- не создаёт `project.godot`, `.tscn`, `.tres`, `.uid` или бинарные примеры внутри репозитория GCA.

## Ограничения версии 0.1.0

- Нет отдельного gameplay tag catalog и tag picker.
- Нет вложенных таблиц для costs, requirements, operations и effect specs.
- Нет reverse-reference graph.
- Нет безопасного rename-ID workflow с migration aliases.
- Нет runtime monitor.
- Нет generated `GameDefinitionCatalog`.
- Нет массового multi-row редактирования.
- Проверка в настоящем Godot 4.6 должна выполняться после переноса файлов в проект, поскольку этот репозиторий не содержит project file.

## Следующие этапы

1. Типизированные effect modifier и meter operation Resources.
2. Gameplay tag catalog и searchable picker.
3. Reverse references и блокировка небезопасного удаления.
4. Definition catalog и runtime resolver.
5. Object archetypes с `PackedScene`.
6. Interaction definitions и integration mappings.
7. Runtime Monitor для effects, abilities, control, resolver и execution queue.
