@tool
extends EditorPlugin
class_name GameDataStudioPlugin

# ======= CONSTS =========
const MAIN_PANEL_SCENE: PackedScene = preload("res://addons/gca_data_studio/ui/ui_gca_data_studio.tscn")

# ======== PRIVATE VAR ======
var _main_panel: GameDataStudioDock = null

# ======= OVERRIDE =======
func _enter_tree() -> void:
	var panel_instance: Node = MAIN_PANEL_SCENE.instantiate()
	_main_panel = panel_instance as GameDataStudioDock
	if _main_panel == null:
		push_error("GCA Data Studio main scene root must inherit GameDataStudioDock.")
		panel_instance.queue_free()
		return
	_main_panel.set_editor_context(get_editor_interface(), get_undo_redo())
	_main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var main_screen: Control = get_editor_interface().get_editor_main_screen()
	main_screen.add_child(_main_panel)
	_main_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_panel.hide()

func _exit_tree() -> void:
	if _main_panel != null:
		_main_panel.queue_free()
		_main_panel = null

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if _main_panel == null:
		return
	_main_panel.visible = visible

func _get_plugin_name() -> String:
	return "GCA Data Studio"

func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon(&"Resource", &"EditorIcons")
