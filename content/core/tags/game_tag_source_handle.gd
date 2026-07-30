extends RefCounted
class_name GameTagSourceHandle

# ======== PRIVATE VAR ======
var _handle_id: int = 0
var _tag_id: StringName = &""
var _source_id: StringName = &""
var _persistent: bool = false
var _valid: bool = true

# ======= OVERRIDE =======
func _init(handle_id: int = 0, tag_id: StringName = &"", source_id: StringName = &"", persistent: bool = false) -> void:
    _handle_id = handle_id
    _tag_id = tag_id
    _source_id = source_id
    _persistent = persistent

# ====== PUBLIC ========
func get_handle_id() -> int:
    return _handle_id

func get_tag_id() -> StringName:
    return _tag_id

func get_source_id() -> StringName:
    return _source_id

func is_persistent() -> bool:
    return _persistent

func is_valid() -> bool:
    return _valid

func invalidate() -> void:
    _valid = false
