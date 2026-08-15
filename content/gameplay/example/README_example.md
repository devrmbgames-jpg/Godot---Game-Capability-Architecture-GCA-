# GCA gameplay examples

Все примеры находятся внутри `res://content/gameplay/example/` и используют только текстовые Godot-ресурсы.

## Сцены

- `mine/prop_mine_example.tscn` — Area3D-мина с GCA identity/tags и радиальным damage через world targeting port.
- `door/prop_door_example.tscn` — интерактивная дверь с динамическими offers Open/Close/Unlock.
- `character/ent_third_person_character_example.tscn` — CharacterBody3D от третьего лица. Эталонный BoxMesh и BoxShape3D имеют размер `1 x 2 x 1` метра.
- `chest/prop_chest_example.tscn` — сундук с reservation-aware offer и простым data snapshot содержимого.
- `enemy/ent_enemy_example.tscn` — враг, управляемый через `GameMockAIControlSource`, с health, damage и death policy.
- `npc/ent_npc_example.tscn` — NPC с scripted control и dialogue offer.
- `inventory/inventory_equipment_example.tscn` — equip/unequip через `GameInventoryAdapter`; binding принадлежит stable item instance ID.
- `dialogue/dialogue_reward_example.tscn` — Dialogue Manager получает query/command surface через `GameDialogueAdapter` и выдаёт ability reward.
- `goap/goap_survival_example.tscn` — GOAP-план `find food → take food → cook food → eat food → sleep`.
- `gallery/gameplay_examples_gallery_example.tscn` — обзорная сцена шести базовых примеров.
- `testing/test_gca_suite_example.tscn` — запускаемая тестовая сцена с UI, сигналами каждого теста и итоговым `suite_completed`.

## Сигналы тестовой сцены

```gdscript
test_started(test_id: StringName)
test_completed(test_id: StringName, passed: bool, message: String)
suite_completed(all_passed: bool, passed_count: int, total_count: int)
```

Публичный API раннера:

```gdscript
run_all_tests()
all_tests_passed() -> bool
get_results() -> Array[Dictionary]
```

## Интеграционный цикл

1. Скопировать `content/gameplay/example/` в проект с GCA и установленными аддонами.
2. Открыть `testing/test_gca_suite_example.tscn`.
3. Запустить сцену; она автоматически выполнит core, scene и integration checks.
4. Следить за UI или сигналом `suite_completed`.
5. Перед сборкой считать сборку допустимой только при `all_passed == true`.

Inventory scene имитирует входящий equip callback вызовом `GameInventoryAdapter.apply_equipment()`. В production этот же вызов подключается к фактическому equip signal используемого Inventory System. Dialogue scene передаёт себя как explicit game state в Dialogue Manager. GOAP scene использует штатные lifecycle `enter/perform/exit` и связывает plugin world state с `GameGOAPAdapter`.
