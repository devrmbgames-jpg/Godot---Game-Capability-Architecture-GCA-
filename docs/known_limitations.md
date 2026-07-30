# Известные ограничения первой версии этапа 1

1. Проверка duplicate stable ID охватывает текущую owned scene. Project-wide и streamed-region validation относятся к этапу 5.
2. `GameObjectHandle` использует локальные weak references; загрузка unresolved-объектов и deferred world commands относятся к этапу 5.
3. Runtime registration атомарна относительно registry/lifecycle ядра, но feature обязан держать собственную инициализацию локальной и обратимой.
4. Identity и основной tag container являются immutable infrastructure после activation; их runtime-замена отклоняется, чтобы не инвалидировать object context и handles.
5. Lazy required dependency является явным исключением: feature может активироваться без поставщика и обязан корректно работать с отсутствующим значением.
6. Debug panel намеренно минимальна и обновляется вызовом `refresh()`.
7. World ports пока внедряются ограниченным словарём; типизированные world-port contracts вводятся этапами-владельцами.
8. Тесты используют самостоятельный runner без стороннего test addon.
9. Headless tests должны быть фактически выполнены в Godot 4.6.x перед окончательной приёмкой.
