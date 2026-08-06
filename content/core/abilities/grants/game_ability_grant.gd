extends RefCounted
## Owner-specific right to activate one [GameAbilityDefinition].
##
## Preserves source ownership, level, charges, priority, runtime overrides, and
## active execution IDs so duplicate definitions from different sources remain
## independent and can be revoked by handle.
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
## Creates a grant and deep-copies source-specific runtime overrides.
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
## Returns the owner-local grant handle.
func get_handle_id() -> int: return _handle_id
## Returns the immutable ability definition.
func get_definition() -> GameAbilityDefinition: return _definition
## Returns the object that owns this grant.
func get_owner_handle() -> GameObjectHandle: return _owner_handle
## Returns the source object that issued the grant, when available.
func get_source_handle() -> GameObjectHandle: return _source_handle
## Returns the stable source definition or binding ID.
func get_source_definition_id() -> StringName: return _source_definition_id
## Returns the grant level.
func get_level() -> int: return _level
## Returns remaining charges; negative values represent unlimited charges.
func get_charges() -> int: return _charges
## Returns the priority used by grant-selection policies.
func get_source_priority() -> int: return _source_priority
## Returns a deep copy of source-specific overrides.
func get_runtime_overrides() -> Dictionary: return _runtime_overrides.duplicate(true)
## Returns whether this grant is both enabled and valid.
func is_enabled() -> bool: return _enabled and _valid
## Enables or disables activation without invalidating grant identity.
func set_enabled(value: bool) -> void: _enabled = value
## Returns whether at least one charge is available.
func has_charge() -> bool: return _charges != 0
## Consumes one finite charge and returns whether consumption succeeded.
func consume_charge() -> bool:
	if _charges == 0: return false
	if _charges > 0: _charges -= 1
	return true
## Restores one finite charge.
func restore_charge() -> void:
	if _charges >= 0: _charges += 1
## Registers an active execution owned by this grant.
func add_execution(execution_id: int) -> void:
	if execution_id not in _active_execution_ids: _active_execution_ids.append(execution_id)
## Removes an execution ID from this grant's active set.
func remove_execution(execution_id: int) -> void: _active_execution_ids.erase(execution_id)
## Returns a copy of active execution IDs.
func get_active_execution_ids() -> Array[int]: return _active_execution_ids.duplicate()
## Returns whether the grant and its definition are valid.
func is_valid() -> bool: return _valid and _definition != null
## Invalidates the grant, disables it, and clears execution ownership records.
func invalidate() -> void: _valid = false; _enabled = false; _active_execution_ids.clear()
## Serializes grant diagnostics without exposing mutable runtime collections.
func to_dictionary() -> Dictionary:
	return {"handle_id": _handle_id, "ability_id": _definition.ability_id if _definition != null else &"", "source_definition_id": _source_definition_id, "level": _level, "charges": _charges, "enabled": _enabled, "source_priority": _source_priority, "active_execution_ids": _active_execution_ids.duplicate()}
