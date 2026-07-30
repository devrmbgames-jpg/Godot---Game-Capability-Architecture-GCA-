extends RefCounted
class_name GameAbilityGrant

# ======== PRIVATE VAR ======
var _handle_id: int = 0
var _definition: GameAbilityDefinition = null
var _owner_handle: GameObjectHandle = null
var _source_handle: GameObjectHandle = null
var _source_definition_id: StringName = &""
var _level: int = 1
var _charges: int = -1
var _enabled: bool = true
var _source_priority: int = 0
var _runtime_overrides: Dictionary = {}
var _active_execution_ids: Array[int] = []
var _valid: bool = true

# ======= OVERRIDE =======
func _init(handle_id: int, definition: GameAbilityDefinition, owner_handle: GameObjectHandle, source_handle: GameObjectHandle = null, source_definition_id: StringName = &"", level: int = 1, charges: int = -1, source_priority: int = 0, runtime_overrides: Dictionary = {}) -> void:
	_handle_id = handle_id
	_definition = definition
	_owner_handle = owner_handle
	_source_handle = source_handle
	_source_definition_id = source_definition_id
	_level = maxi(1, level)
	_charges = charges
	_source_priority = source_priority
	_runtime_overrides = runtime_overrides.duplicate(true)

# ====== PUBLIC ========
func get_handle_id() -> int: return _handle_id
func get_definition() -> GameAbilityDefinition: return _definition
func get_owner_handle() -> GameObjectHandle: return _owner_handle
func get_source_handle() -> GameObjectHandle: return _source_handle
func get_source_definition_id() -> StringName: return _source_definition_id
func get_level() -> int: return _level
func get_charges() -> int: return _charges
func get_source_priority() -> int: return _source_priority
func get_runtime_overrides() -> Dictionary: return _runtime_overrides.duplicate(true)
func is_enabled() -> bool: return _enabled and _valid
func set_enabled(value: bool) -> void: _enabled = value
func has_charge() -> bool: return _charges != 0
func consume_charge() -> bool:
	if _charges == 0: return false
	if _charges > 0: _charges -= 1
	return true
func restore_charge() -> void:
	if _charges >= 0: _charges += 1
func add_execution(execution_id: int) -> void:
	if execution_id not in _active_execution_ids: _active_execution_ids.append(execution_id)
func remove_execution(execution_id: int) -> void: _active_execution_ids.erase(execution_id)
func get_active_execution_ids() -> Array[int]: return _active_execution_ids.duplicate()
func is_valid() -> bool: return _valid and _definition != null
func invalidate() -> void: _valid = false; _enabled = false; _active_execution_ids.clear()
func to_dictionary() -> Dictionary:
	return {"handle_id": _handle_id, "ability_id": _definition.ability_id if _definition != null else &"", "source_definition_id": _source_definition_id, "level": _level, "charges": _charges, "enabled": _enabled, "source_priority": _source_priority, "active_execution_ids": _active_execution_ids.duplicate()}
