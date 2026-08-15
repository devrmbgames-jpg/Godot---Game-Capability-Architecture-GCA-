extends RefCounted
## Runtime source-owned binding between one logical ability slot and one grant handle.
##
## Multiple bindings can target the same slot. Priority and creation order determine
## which valid grant is active without mutating or replacing lower-priority bindings.
class_name GameAbilitySlotBinding

# ======== PRIVATE VAR ======
var _handle_id: int = 0
var _slot_id: StringName = &""
var _grant_handle_id: int = 0
var _source_id: StringName = &""
var _priority: int = 0

# ======= OVERRIDE =======
## Creates one immutable runtime binding record.
func _init(
	handle_id: int,
	slot_id: StringName,
	grant_handle_id: int,
	source_id: StringName = &"",
	priority: int = 0
) -> void:
	_handle_id = handle_id
	_slot_id = slot_id
	_grant_handle_id = grant_handle_id
	_source_id = source_id
	_priority = priority

# ====== PUBLIC ========
## Returns the owner-local binding handle.
func get_handle_id() -> int:
	return _handle_id

## Returns the logical slot identifier.
func get_slot_id() -> StringName:
	return _slot_id

## Returns the bound ability grant handle.
func get_grant_handle_id() -> int:
	return _grant_handle_id

## Returns the source key that owns this binding.
func get_source_id() -> StringName:
	return _source_id

## Returns the binding priority. Higher values win.
func get_priority() -> int:
	return _priority

## Returns whether the binding has the minimum required identity.
func is_valid() -> bool:
	return _handle_id > 0 and not _slot_id.is_empty() and _grant_handle_id > 0

## Serializes the binding for diagnostics.
func to_dictionary() -> Dictionary:
	return {
		"handle_id": _handle_id,
		"slot_id": _slot_id,
		"grant_handle_id": _grant_handle_id,
		"source_id": _source_id,
		"priority": _priority,
	}
