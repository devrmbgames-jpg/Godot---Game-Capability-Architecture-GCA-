# Game Capability Architecture — Этап 1 Foundation

Пакет реализует первый этап GCA на строго типизированном GDScript для Godot Engine 4.6.

## Реализовано

- локальный composition root `GameObjectKernel`;
- lifecycle и metadata-контракт `GameFeature`;
- локальный capability registry с `exclusive`, `optional exclusive` и `multi` cardinality;
- обязательные, опциональные и явно lazy dependencies с кешированием;
- стабильная identity и weak runtime handles;
- адресные command/query contracts и локальные events;
- структурированный `GameCommandResult`;
- execution context с root/parent lineage, seed и captured values;
- FIFO operation queue с depth limit, root budget, cancellation и cycle guard;
- gameplay tags с несколькими source handles и расширяемым `GameTagCatalog`;
- безопасная runtime-регистрация/снятие features;
- rollback частично выполненной инициализации;
- diagnostics, history команд/событий/операций и минимальная debug panel;
- mock-features, headless test runner и две демонстрационные сцены.

## Запуск тестов

```bash
godot --headless --path /path/to/GCA_Stage1_Foundation
```

Либо использовать `tools/run_headless_tests.sh` / `tools/run_headless_tests.ps1`. Переменная `GODOT_BIN` позволяет указать путь к конкретному binary.

Test runner завершает процесс с кодом `0`, когда все assertions прошли, и `1` при наличии ошибок.

## Импорт в существующий проект

Скопировать `content/core/` в `res://content/core/` целевого проекта. Пакет не импортирует GOAP, Dialogue Manager, Inventory System и не содержит attributes, effects, damage, abilities, input или AI.

## Демонстрационные сцены

- `res://content/core/testing/scenes/test_logical_object.tscn` — чистый логический `Node`;
- `res://content/core/testing/scenes/prop_test_foundation_body.tscn` — `RigidBody3D`-проп-заглушка;
- обе сцены используют один и тот же `GameObjectKernel` без общего доменного суперкласса.
