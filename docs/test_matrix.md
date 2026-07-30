# Матрица автоматизированных тестов этапа 1

Headless runner покрывает:

- валидный lifecycle и dependency order;
- deactivation/read-only query/reactivation;
- кеширование required capability;
- multi capability resolution;
- command mutation и structured result;
- query без mutation;
- детерминированную доставку local events;
- безопасную очередь вложенных events;
- root/parent execution lineage;
- operation queue processing;
- multi-source tag ownership;
- handle invalidation;
- missing required capability;
- duplicate exclusive provider;
- dependency cycle;
- duplicate feature ID;
- duplicate feature type без разрешения multiple instances;
- cycle guard, root operation budget и root cancellation;
- invalid command target;
- runtime removal во время event iteration;
- запрет runtime-замены identity/tag infrastructure;
- explicit lazy dependency;
- dynamic registration и required capability loss.

Editor warnings реализованы в kernel, feature, identity, tag container и debug panel. Реакцию редактора на изменение конфигурации необходимо проверить smoke-тестом в целевой установке Godot 4.6.x.
