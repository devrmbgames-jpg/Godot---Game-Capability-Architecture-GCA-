# Отчёт архитектурного соответствия

- Не введён доменный суперкласс персонажа/сущности/разрушаемого объекта.
- Kernel не хранит health, movement, inventory, abilities, effects или AI state.
- Features являются прямыми дочерними узлами kernel и не вызывают sibling-features через иерархию.
- Upward communication выполняется сигналами feature → kernel.
- Downward command routing выполняется прямыми вызовами kernel → feature.
- Межиерархические ссылки представлены export-link или `GameObjectHandle`.
- SceneTree traversal используется только при assembly/editor validation, но не в gameplay hot loop.
- Capability registry локален одному объекту.
- Shared Resources содержат metadata; runtime state находится в Nodes или лёгких `RefCounted`.
- Tags принадлежат source handles, а дополнительные IDs задаются через `GameTagCatalog`.
- `content/core` не импортирует внешние аддоны.
