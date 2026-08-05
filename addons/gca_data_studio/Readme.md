# GCA Data Studio

`GCA Data Studio` — editor-only плагин для табличной работы с data-driven определениями Game Capability Architecture в Godot Engine 4.6.

Плагин не заменяет Godot `Resource`, SceneTree или Inspector. Он индексирует обычные `.tres`/`.res` definitions, показывает их в едином интерфейсе, позволяет изменять простые поля, создавать новые определения и выполнять проектную валидацию.

## Текущая версия

Версия `0.2.0` включает:

- отдельный main-screen редактора `GCA Data Studio`;
- полноценную редактируемую UI-сцену;
- экспортируемые ссылки на ключевые панели, контейнеры и контролы;
- рекурсивное индексирование GCA Resources из `res://content`;
- таблицы Attributes, Meters, Effects и Abilities;
- общий список индексируемых definitions;
- поиск по ID, имени, типу и пути;
- inline-редактирование строк, чисел, bool, enum и массивов `StringName`;
- просмотр выбранного ресурса через стандартный `EditorInspector`;
- создание новых definition Resources;
- сохранение через `ResourceSaver`;
- интеграцию изменений с `EditorUndoRedoManager`;
- validation stable IDs и связей между definitions.

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

## UI-сцена

Основной интерфейс хранится в сцене:

```text
res://addons/gca_data_studio/ui/ui_gca_data_studio.tscn
```

`GameDataStudioPlugin` инстанцирует эту сцену как обычный `PackedScene`. Скрипт больше не создаёт панели и поля программно.

Базовая иерархия:

```text
GCADataStudio
└── RootMargin
    └── RootLayout
        ├── ToolbarPanel
        │   └── ToolbarMargin
        │       └── ToolbarContainer
        ├── WorkspaceSplit
        │   ├── NavigationPanel
        │   │   └── NavigationMargin
        │   │       └── NavigationContainer
        │   └── ContentSplit
        │       ├── TablePanel
        │       │   └── TableMargin
        │       │       └── TableContainer
        │       └── InspectorPanel
        │           └── InspectorMargin
        │               └── InspectorContainer
        └── FooterPanel
            └── FooterMargin
                └── FooterContainer
```

Такое разделение позволяет менять внешний вид прямо в Godot Editor:

- размеры и `custom_minimum_size` панелей;
- отступы `MarginContainer`;
- `split_offset` разделителей;
- порядок и расположение областей;
- Theme и theme overrides;
- подписи и размеры заголовков;
- оформление кнопок, таблицы и Inspector;
- дополнительные декоративные или служебные Controls.

## Экспортируемые ссылки сцены

Корневой `GameDataStudioDock` содержит две группы экспортов.

### Scene Layout

```text
root_layout
toolbar_panel
toolbar_container
workspace_split
navigation_panel
navigation_container
content_split
table_panel
table_container
inspector_panel
inspector_container
footer_panel
footer_container
```

Эти ссылки предназначены для ключевых областей дизайна. В контейнеры можно добавлять собственные подписи, разделители, панели, подсказки и другие элементы.

### Scene Controls

```text
title_label
navigation_title_label
table_title_label
inspector_title_label
category_list
search_edit
definition_table
definition_inspector
status_label
refresh_button
validate_button
create_button
```

Эти Controls используются логикой плагина. Их можно перемещать и стилизовать, пока экспортированные ссылки остаются назначенными и типы узлов совместимы с полями.

### Правила редизайна

Можно:

- переименовывать и перемещать узлы через Scene dock;
- оборачивать области дополнительными Containers;
- менять PanelContainer, MarginContainer и SplitContainer настройки;
- назначать собственную Theme;
- добавлять новые Controls внутрь экспортированных контейнеров;
- менять тексты заголовков и кнопок.

Нельзя без изменения скрипта:

- очищать обязательные exported references;
- заменять `Tree`, `ItemList`, `LineEdit` или `EditorInspector` несовместимым типом;
- удалять функциональные кнопки, не назначив вместо них другие;
- отсоединять корневой скрипт `GameDataStudioDock`.

При отсутствующей ссылке плагин выводит понятную editor error с именем незаполненного export-поля.

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
- другие `Game*` Resources со стабильным ID-полем.

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

Сырые текстуры, модели, материалы и Resources без GCA ID в таблицу не попадают.

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

В таблице доступны stable ID, display name, passive state, cooldown, channels, conflict policy, persistence flags и schema version.

Requirements, costs и operations остаются вложенными Resources и редактируются через Inspector.

## Создание Definition

1. Выбрать категорию Attributes, Meters, Effects или Abilities.
2. Нажать `Create`.
3. Плагин создаст новый Resource в стандартном каталоге категории.
4. Отредактировать stable ID и остальные поля в таблице или Inspector.

Стандартные каталоги:

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

## Inline-редактирование

Поддерживаются:

- `String` и `StringName`;
- `int`;
- `float`;
- `bool`;
- enum;
- массивы строковых ID через значения, разделённые запятыми.

Изменения применяются к исходному Resource и сохраняются. Undo/Redo проходит через `EditorUndoRedoManager`.

Сложные значения редактируются через Inspector:

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
    ├── ui_gca_data_studio.tscn
    └── game_data_studio_dock.gd
```

### GameDataSchemaRegistry

Описывает поддерживаемые definition classes, ID/display properties, таблицы, типы ячеек, каталоги создания и правила имён файлов.

### GameDataIndex

Отвечает за обход каталогов, загрузку `.tres`/`.res`, определение класса и stable ID, сортировку, поиск и хранение validation issues.

### GameDataValidator

Выполняет common и type-specific проверки. Валидатор не изменяет данные.

### GameDataStudioDock

Содержит логику таблицы, Inspector, индекса, валидатора, создания и Undo/Redo. Визуальные узлы получает через exported scene references.

### ui_gca_data_studio.tscn

Является единственным источником UI-композиции Data Studio. `EditorPlugin` инстанцирует её как `PackedScene`.

## Архитектурные ограничения

Плагин:

- editor-only;
- не импортируется из `content/core`;
- не используется runtime-кодом;
- не заменяет SceneTree или Inspector;
- не создаёт скрытые gameplay-компоненты;
- не хранит runtime handles как persistent IDs;
- не изменяет shared definitions во время игры;
- не редактирует NodePath-ссылки между gameplay-узлами через таблицу.

## Ограничения версии 0.2.0

- Нет отдельного gameplay tag catalog и tag picker.
- Нет вложенных таблиц для costs, requirements, operations и effect specs.
- Нет reverse-reference graph.
- Нет безопасного rename-ID workflow с migration aliases.
- Нет runtime monitor.
- Нет generated `GameDefinitionCatalog`.
- Нет массового multi-row редактирования.

## Следующие этапы

1. Типизированные effect modifier и meter operation Resources.
2. Gameplay tag catalog и searchable picker.
3. Reverse references и блокировка небезопасного удаления.
4. Definition catalog и runtime resolver.
5. Object archetypes с `PackedScene`.
6. Interaction definitions и integration mappings.
7. Runtime Monitor для effects, abilities, control, resolver и execution queue.
