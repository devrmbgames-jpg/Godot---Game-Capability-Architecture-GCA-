@tool
extends Control
class_name GameDataStudioDock

# ======= CONSTS =========
const INDEX_SCRIPT: Script = preload("res://addons/gca_data_studio/core/game_data_index.gd")
const VALIDATOR_SCRIPT: Script = preload("res://addons/gca_data_studio/core/game_data_validator.gd")
const SCHEMA_SCRIPT: Script = preload("res://addons/gca_data_studio/core/game_data_schema_registry.gd")

# ======== PRIVATE VAR ======
var _editor_interface: EditorInterface = null
var _undo_redo: EditorUndoRedoManager = null
var _index: GameDataIndex = null
var _validator: GameDataValidator = null
var _category_list: ItemList = null
var _search_edit: LineEdit = null
var _table: Tree = null
var _inspector: EditorInspector = null
var _status_label: Label = null
var _selected_class: StringName = &""
var _visible_records: Array[Dictionary] = []
var _edited_resource: Resource = null
var _suppress_table_signal: bool = false

# ======= OVERRIDE =======
func _ready() -> void:
	name = "GCADataStudio"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_index = INDEX_SCRIPT.new() as GameDataIndex
	_validator = VALIDATOR_SCRIPT.new() as GameDataValidator
	_build_ui()
	_rebuild_index()

# ====== HELPERS ========
func _build_ui() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var toolbar: HBoxContainer = HBoxContainer.new()
	root.add_child(toolbar)

	var title: Label = Label.new()
	title.text = "GCA Data Studio"
	title.add_theme_font_size_override(&"font_size", 20)
	toolbar.add_child(title)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search ID, name or path"
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(_on_search_changed)
	toolbar.add_child(_search_edit)

	var refresh_button: Button = Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_rebuild_index)
	toolbar.add_child(refresh_button)

	var validate_button: Button = Button.new()
	validate_button.text = "Validate"
	validate_button.pressed.connect(_validate_project)
	toolbar.add_child(validate_button)

	var create_button: Button = Button.new()
	create_button.text = "Create"
	create_button.pressed.connect(_create_definition)
	toolbar.add_child(create_button)

	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	_category_list = ItemList.new()
	_category_list.custom_minimum_size.x = 190.0
	_category_list.item_selected.connect(_on_category_selected)
	split.add_child(_category_list)

	var center_split: HSplitContainer = HSplitContainer.new()
	split.add_child(center_split)

	_table = Tree.new()
	_table.hide_root = true
	_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_table.item_selected.connect(_on_table_selection_changed)
	_table.item_edited.connect(_on_table_item_edited)
	center_split.add_child(_table)

	var right_panel: VBoxContainer = VBoxContainer.new()
	right_panel.custom_minimum_size.x = 360.0
	center_split.add_child(right_panel)

	var inspector_title: Label = Label.new()
	inspector_title.text = "Definition"
	inspector_title.add_theme_font_size_override(&"font_size", 16)
	right_panel.add_child(inspector_title)

	_inspector = EditorInspector.new()
	_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(_inspector)

	_status_label = Label.new()
	_status_label.text = "Ready"
	root.add_child(_status_label)

func _rebuild_index() -> void:
	_index.rebuild("res://content")
	_populate_categories()
	_refresh_table()
	_status_label.text = "Indexed %d definitions" % _index.get_record_count()

func _populate_categories() -> void:
	_category_list.clear()
	_category_list.add_item("All")
	_category_list.set_item_metadata(0, &"")
	var classes: Array[StringName] = _index.get_resource_classes()
	for resource_class: StringName in classes:
		var item_index: int = _category_list.add_item(SCHEMA_SCRIPT.get_category_title(resource_class))
		_category_list.set_item_metadata(item_index, resource_class)
	_category_list.select(0)
	_selected_class = &""

func _refresh_table() -> void:
	_suppress_table_signal = true
	_table.clear()
	var records: Array[Dictionary] = _index.get_records(_selected_class)
	_visible_records.clear()
	var query: String = _search_edit.text.strip_edges().to_lower()
	for record: Dictionary in records:
		if not query.is_empty() and not _record_matches(record, query):
			continue
		_visible_records.append(record)
	_configure_columns()
	var root: TreeItem = _table.create_item()
	for record: Dictionary in _visible_records:
		_add_record_row(root, record)
	_suppress_table_signal = false

func _record_matches(record: Dictionary, query: String) -> bool:
	var haystack: String = "%s %s %s %s" % [
		str(record.get("id", "")),
		str(record.get("display_name", "")),
		str(record.get("path", "")),
		str(record.get("resource_class", "")),
	]
	return query in haystack.to_lower()

func _configure_columns() -> void:
	var columns: Array[Dictionary] = _get_active_columns()
	_table.columns = columns.size() + 2
	_table.set_column_title(0, "Status")
	_table.set_column_title(1, "Path")
	_table.set_column_titles_visible(true)
	for index: int in range(columns.size()):
		_table.set_column_title(index + 2, str(columns[index].get("title", "Value")))

func _get_active_columns() -> Array[Dictionary]:
	if not _selected_class.is_empty():
		return SCHEMA_SCRIPT.get_columns(_selected_class)
	return [
		{"property": &"__id", "title": "ID", "editable": false, "kind": &"text"},
		{"property": &"__class", "title": "Type", "editable": false, "kind": &"text"},
	]

func _add_record_row(parent: TreeItem, record: Dictionary) -> void:
	var item: TreeItem = _table.create_item(parent)
	var resource: Resource = record.get("resource") as Resource
	var issues: Array = record.get("issues", []) as Array
	item.set_text(0, _format_status(issues))
	item.set_tooltip_text(0, _format_issues(issues))
	item.set_text(1, str(record.get("path", "")))
	item.set_metadata(0, str(record.get("path", "")))
	var columns: Array[Dictionary] = _get_active_columns()
	for index: int in range(columns.size()):
		var column: Dictionary = columns[index]
		var property_name: StringName = column.get("property", &"")
		var value: Variant
		if property_name == &"__id":
			value = record.get("id", &"")
		elif property_name == &"__class":
			value = record.get("resource_class", &"")
		else:
			value = resource.get(property_name) if resource != null else null
		_write_cell(item, index + 2, value, column)

func _write_cell(item: TreeItem, column_index: int, value: Variant, column: Dictionary) -> void:
	var kind: StringName = column.get("kind", &"text")
	var editable: bool = bool(column.get("editable", false))
	match kind:
		&"bool":
			item.set_cell_mode(column_index, TreeItem.CELL_MODE_CHECK)
			item.set_checked(column_index, bool(value))
		&"enum":
			item.set_cell_mode(column_index, TreeItem.CELL_MODE_RANGE)
			var options: Array = column.get("options", []) as Array
			item.set_text(column_index, ",".join(PackedStringArray(options)))
			item.set_range(column_index, float(value))
		&"int", &"float":
			item.set_cell_mode(column_index, TreeItem.CELL_MODE_RANGE)
			item.set_range_config(column_index, -1000000.0, 1000000.0, 1.0 if kind == &"int" else 0.01)
			item.set_range(column_index, float(value))
		&"string_names":
			item.set_text(column_index, _join_values(value))
		_:
			item.set_text(column_index, str(value))
	item.set_editable(column_index, editable)

func _join_values(value: Variant) -> String:
	if not value is Array:
		return str(value)
	var strings: PackedStringArray = PackedStringArray()
	for entry: Variant in value as Array:
		strings.append(str(entry))
	return ", ".join(strings)

func _format_status(issues: Array) -> String:
	var errors: int = 0
	var warnings: int = 0
	for issue_value: Variant in issues:
		var issue: Dictionary = issue_value as Dictionary
		if StringName(issue.get("severity", &"warning")) == &"error":
			errors += 1
		else:
			warnings += 1
	if errors > 0:
		return "Error (%d)" % errors
	if warnings > 0:
		return "Warning (%d)" % warnings
	return "Valid"

func _format_issues(issues: Array) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for issue_value: Variant in issues:
		var issue: Dictionary = issue_value as Dictionary
		lines.append("%s: %s" % [issue.get("severity", "warning"), issue.get("message", "")])
	return "\n".join(lines)

func _validate_project() -> void:
	var report: Dictionary = _validator.validate(_index)
	_refresh_table()
	_status_label.text = "Validated %d definitions: %d errors, %d warnings" % [
		int(report.get("record_count", 0)),
		int(report.get("error_count", 0)),
		int(report.get("warning_count", 0)),
	]

func _create_definition() -> void:
	if _selected_class.is_empty():
		_status_label.text = "Select a definition category before creating data"
		return
	var schema: Dictionary = SCHEMA_SCRIPT.get_creation_schema(_selected_class)
	var script_path: String = str(schema.get("script_path", ""))
	var script: Script = load(script_path) as Script
	if script == null:
		_status_label.text = "Definition script not found: %s" % script_path
		return
	var resource: Resource = script.new() as Resource
	if resource == null:
		_status_label.text = "Could not instantiate %s" % _selected_class
		return
	var folder: String = str(schema.get("default_folder", "res://content/gameplay"))
	var prefix: String = str(schema.get("file_prefix", "definition_"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var path: String = _find_free_path(folder, prefix)
	var error: Error = ResourceSaver.save(resource, path)
	if error != OK:
		_status_label.text = "Could not save definition: %s" % error_string(error)
		return
	_editor_interface.get_resource_filesystem().scan()
	_rebuild_index()
	_select_path(path)
	_status_label.text = "Created %s" % path

func _find_free_path(folder: String, prefix: String) -> String:
	var index: int = 1
	while true:
		var candidate: String = folder.path_join("%snew_%03d.tres" % [prefix, index])
		if not ResourceLoader.exists(candidate):
			return candidate
		index += 1
	return folder.path_join("%snew.tres" % prefix)

func _select_path(path: String) -> void:
	var root: TreeItem = _table.get_root()
	if root == null:
		return
	var item: TreeItem = root.get_first_child()
	while item != null:
		if str(item.get_metadata(0)) == path:
			item.select(0)
			_table.scroll_to_item(item)
			_on_table_selection_changed()
			return
		item = item.get_next()

func _read_cell_value(item: TreeItem, column_index: int, column: Dictionary) -> Variant:
	var kind: StringName = column.get("kind", &"text")
	match kind:
		&"bool":
			return item.is_checked(column_index)
		&"enum", &"int":
			return int(item.get_range(column_index))
		&"float":
			return float(item.get_range(column_index))
		&"string_names":
			var values: Array[StringName] = []
			for part: String in item.get_text(column_index).split(",", false):
				var cleaned: String = part.strip_edges()
				if not cleaned.is_empty():
					values.append(StringName(cleaned))
			return values
		_:
			return item.get_text(column_index)

func _apply_property_change(resource: Resource, property_name: StringName, value: Variant, path: String) -> void:
	if _undo_redo == null:
		resource.set(property_name, value)
		ResourceSaver.save(resource, path)
		return
	var previous_value: Variant = resource.get(property_name)
	_undo_redo.create_action("Edit GCA definition")
	_undo_redo.add_do_property(resource, property_name, value)
	_undo_redo.add_undo_property(resource, property_name, previous_value)
	_undo_redo.add_do_method(self, &"_save_resource", resource, path)
	_undo_redo.add_undo_method(self, &"_save_resource", resource, path)
	_undo_redo.commit_action()

# ====== PUBLIC ========
func set_editor_context(editor_interface: EditorInterface, undo_redo: EditorUndoRedoManager) -> void:
	_editor_interface = editor_interface
	_undo_redo = undo_redo

func _save_resource(resource: Resource, path: String) -> void:
	ResourceSaver.save(resource, path)
	_index.refresh_record(path)
	_validate_project()

# ===== SLOTS =======
func _on_category_selected(index: int) -> void:
	_selected_class = StringName(_category_list.get_item_metadata(index))
	_refresh_table()

func _on_search_changed(_text: String) -> void:
	_refresh_table()

func _on_table_selection_changed() -> void:
	var item: TreeItem = _table.get_selected()
	if item == null:
		return
	var path: String = str(item.get_metadata(0))
	var record: Dictionary = _index.get_record(path)
	_edited_resource = record.get("resource") as Resource
	_inspector.edit(_edited_resource)
	if _editor_interface != null and _edited_resource != null:
		_editor_interface.edit_resource(_edited_resource)

func _on_table_item_edited() -> void:
	if _suppress_table_signal:
		return
	var item: TreeItem = _table.get_edited()
	var edited_column: int = _table.get_edited_column()
	if item == null or edited_column < 2 or _selected_class.is_empty():
		return
	var columns: Array[Dictionary] = _get_active_columns()
	var column_index: int = edited_column - 2
	if column_index < 0 or column_index >= columns.size():
		return
	var column: Dictionary = columns[column_index]
	var property_name: StringName = column.get("property", &"")
	var path: String = str(item.get_metadata(0))
	var record: Dictionary = _index.get_record(path)
	var resource: Resource = record.get("resource") as Resource
	if resource == null or property_name.is_empty():
		return
	var value: Variant = _read_cell_value(item, edited_column, column)
	_apply_property_change(resource, property_name, value, path)
