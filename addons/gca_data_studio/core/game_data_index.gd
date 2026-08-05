@tool
extends RefCounted
class_name GameDataIndex

signal index_rebuilt(record_count: int)

# ======== PRIVATE VAR ======
var _records: Array[Dictionary] = []
var _records_by_class: Dictionary = {}
var _records_by_path: Dictionary = {}
var _scan_root: String = "res://content"

# ====== HELPERS ========
func _scan_directory(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if entry_name.begins_with("."):
			entry_name = directory.get_next()
			continue
		var entry_path: String = path.path_join(entry_name)
		if directory.current_is_dir():
			_scan_directory(entry_path)
		elif entry_name.get_extension().to_lower() in ["tres", "res"]:
			_index_resource(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()

func _index_resource(path: String) -> void:
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	if resource == null or not GameDataSchemaRegistry.is_indexable(resource):
		return
	var resource_class: StringName = GameDataSchemaRegistry.detect_resource_class(resource)
	var record: Dictionary = {
		"path": path,
		"resource": resource,
		"resource_class": resource_class,
		"id": GameDataSchemaRegistry.get_resource_id(resource, resource_class),
		"display_name": GameDataSchemaRegistry.get_display_name(resource, resource_class),
		"issues": [],
		"error_count": 0,
		"warning_count": 0,
	}
	_records.append(record)
	_records_by_path[path] = record
	var class_records: Array = _records_by_class.get(resource_class, [])
	class_records.append(record)
	_records_by_class[resource_class] = class_records

func _sort_records() -> void:
	_records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var class_a: String = String(a.get("resource_class", &""))
		var class_b: String = String(b.get("resource_class", &""))
		if class_a != class_b:
			return class_a < class_b
		var id_a: String = String(a.get("id", &""))
		var id_b: String = String(b.get("id", &""))
		if id_a != id_b:
			return id_a < id_b
		return String(a.get("path", "")) < String(b.get("path", ""))
	)
	for resource_class: StringName in _records_by_class.keys():
		var class_records: Array = _records_by_class[resource_class]
		class_records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var id_a: String = String(a.get("id", &""))
			var id_b: String = String(b.get("id", &""))
			if id_a != id_b:
				return id_a < id_b
			return String(a.get("path", "")) < String(b.get("path", ""))
		)
		_records_by_class[resource_class] = class_records

# ====== PUBLIC ========
func rebuild(scan_root: String = "res://content") -> int:
	_scan_root = scan_root.strip_edges()
	if _scan_root.is_empty():
		_scan_root = "res://content"
	_records.clear()
	_records_by_class.clear()
	_records_by_path.clear()
	_scan_directory(_scan_root)
	_sort_records()
	index_rebuilt.emit(_records.size())
	return _records.size()

func get_scan_root() -> String:
	return _scan_root

func get_records(resource_class: StringName = &"") -> Array[Dictionary]:
	var source: Array = _records if resource_class.is_empty() else _records_by_class.get(resource_class, [])
	var result: Array[Dictionary] = []
	for record: Dictionary in source:
		result.append(record)
	return result

func get_records_for_class(resource_class: StringName) -> Array[Dictionary]:
	return get_records(resource_class)

func get_record(path: String) -> Dictionary:
	return _records_by_path.get(path, {}) as Dictionary

func get_record_count() -> int:
	return _records.size()

func get_resource_classes() -> Array[StringName]:
	var result: Array[StringName] = []
	for resource_class: StringName in _records_by_class.keys():
		result.append(resource_class)
	result.sort_custom(func(a: StringName, b: StringName) -> bool:
		var title_a: String = GameDataSchemaRegistry.get_category_title(a)
		var title_b: String = GameDataSchemaRegistry.get_category_title(b)
		if title_a != title_b:
			return title_a < title_b
		return String(a) < String(b)
	)
	return result

func update_record_issues(path: String, issues: Array[Dictionary]) -> void:
	if not _records_by_path.has(path):
		return
	var error_count: int = 0
	var warning_count: int = 0
	for issue: Dictionary in issues:
		match StringName(issue.get("severity", &"warning")):
			&"error":
				error_count += 1
			&"warning":
				warning_count += 1
	var record: Dictionary = _records_by_path[path]
	record["issues"] = issues
	record["error_count"] = error_count
	record["warning_count"] = warning_count

func refresh_record(path: String) -> void:
	if not _records_by_path.has(path):
		return
	var record: Dictionary = _records_by_path[path]
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if resource == null:
		return
	var resource_class: StringName = GameDataSchemaRegistry.detect_resource_class(resource)
	record["resource"] = resource
	record["resource_class"] = resource_class
	record["id"] = GameDataSchemaRegistry.get_resource_id(resource, resource_class)
	record["display_name"] = GameDataSchemaRegistry.get_display_name(resource, resource_class)
