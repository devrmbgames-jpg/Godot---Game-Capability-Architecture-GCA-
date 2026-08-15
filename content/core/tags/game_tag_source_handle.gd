extends RefCounted
## Runtime ownership handle for one source contribution to a gameplay tag.
##
## Multiple handles may grant the same tag simultaneously. Removing or invalidating one
## handle does not remove contributions owned by other sources.
class_name GameTagSourceHandle

# ======== PRIVATE VAR ======
var _handle_id: int = 0
var _tag_id: StringName = &""
var _source_id: StringName = &""
var _persistent: bool = false
var _valid: bool = true

# ======= OVERRIDE =======
## Creates a tag ownership handle with stable source and persistence metadata.
func _init(handle_id: int = 0, tag_id: StringName = &"", source_id: StringName = &"", persistent: bool = false) -> void:
	_handle_id = handle_id
	_tag_id = tag_id
	_source_id = source_id
	_persistent = persistent

# ====== PUBLIC ========
## Returns the runtime handle identifier.
func get_handle_id() -> int:
	return _handle_id

## Returns the exact tag granted by this handle.
func get_tag_id() -> StringName:
	return _tag_id

## Returns the logical source identifier that owns this contribution.
func get_source_id() -> StringName:
	return _source_id

## Returns whether this source contribution is eligible for persistence.
func is_persistent() -> bool:
	return _persistent

## Returns whether this runtime handle is still valid.
func is_valid() -> bool:
	return _valid

## Invalidates this handle after its source contribution is removed.
func invalidate() -> void:
	_valid = false
