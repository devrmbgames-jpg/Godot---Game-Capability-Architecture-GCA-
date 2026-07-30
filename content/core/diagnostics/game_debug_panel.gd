@tool
extends PanelContainer
class_name GameDebugPanel

# ======= ON READY ========
@onready var _text_view: RichTextLabel = %TextView

# ======== EXPORT =========
@export var link_kernel: GameObjectKernel = null
@export var pretty_print: bool = true

# ======= OVERRIDE =======
func _ready() -> void:
    refresh()

func _get_configuration_warnings() -> PackedStringArray:
    var warnings := PackedStringArray()
    if link_kernel == null:
        warnings.append("GameDebugPanel requires link_kernel because it belongs to another hierarchy.")
    return warnings

# ====== PUBLIC ========
func refresh() -> void:
    if not is_node_ready() or _text_view == null:
        return
    if link_kernel == null:
        _text_view.text = "No kernel linked."
        return
    _text_view.text = JSON.stringify(link_kernel.get_debug_snapshot(), "  " if pretty_print else "")
