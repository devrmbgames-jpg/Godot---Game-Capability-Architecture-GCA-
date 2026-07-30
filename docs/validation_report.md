# Отчёт проверки — GCA Этап 1

## Выполненные проверки

- 35 GDScript-файлов и 35 уникальных `class_name`;
- все игровые классы имеют префикс `Game`;
- все `res://`-ссылки из скриптов и сцен разрешаются внутри пакета;
- `load_steps` сцен согласованы с числом внешних и встроенных ресурсов;
- не обнаружены `get_parent().foo()`, `Input.*`, `has_method()` как контракт или импорты внешних аддонов;
- не обнаружены отсутствующие файлы сцен/скриптов;
- выполнена проверка баланса скобок и базовой структуры исходников;
- создан SHA-256 manifest всех файлов пакета.

## Автоматизированные сценарии, включённые в runner

- корректный lifecycle и порядок dependencies;
- deactivation, read-only query и reactivation;
- кеш required capability и multi-provider capability;
- command/event/query flow;
- nested local event delivery без рекурсивного обхода коллекции;
- execution root/parent lineage;
- source-owned gameplay tags;
- invalidation object handle;
- missing required capability;
- duplicate exclusive provider;
- dependency cycle;
- duplicate feature ID и запрещённый duplicate feature type;
- operation budget, cycle guard и cancellation root chain;
- invalid target;
- runtime removal во время event delivery;
- immutable identity/tag infrastructure после activation;
- lazy dependency resolution;
- dynamic registration и реакция на потерю required capability.

## Ограничение проверки

В текущем окружении отсутствует исполняемый файл Godot, а сетевой доступ контейнера не позволил загрузить официальный binary. Поэтому headless runner здесь не исполнялся. Перед принятием этапа требуется открыть пакет в установленном Godot 4.6.x и выполнить команду запуска тестов из README.
