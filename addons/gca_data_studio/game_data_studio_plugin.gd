@tool
extends EditorPlugin
class_name GameDataStudioPlugin

# ======= CONSTS =========
const MAIN_PANEL_SCRIPT: Script = preload("res://addons/gca_data_studio/ui/game_data_studio_dock.gd")

# ======== PRIVATE VAR ======
var _main_panel: GameDataStudioDock = null

# ======= OVERRIDE =======
func _enter_tree() -> void:
	_main_panel = MAIN_PANEL_SCRIPT.new() as GameDataStudioDock
	_main_panel.set_editor_context(get_editor_interface(), get_undo_redo())
	get_editor_interface().get_editor_main_screen().add_child(_main_panel)
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
