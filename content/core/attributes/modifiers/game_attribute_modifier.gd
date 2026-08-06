extends RefCounted
## Runtime modifier applied to one [GameAttributeValue].
##
## The modifier keeps stable ownership metadata so it can be updated or removed by
## handle, source, or owning effect instead of using reverse arithmetic.
class_name GameAttributeModifier

# ======= ENUMS =========
enum Operation { ADD, INCREASE }

# ======== PRIVATE VAR ======
var _handle_id: int = 0
var _target_attribute_id: StringName = &""
var _operation: Operation = Operation.ADD
var _magnitude: float = 0.0
var _source_id: StringName = &""
var _owning_effect_handle: int = 0
var _priority: int = 0
var _creation_index: int = 0
var _valid: bool = true

# ======= OVERRIDE =======
## Creates a modifier with deterministic ordering and ownership metadata.
func _init(handle_id: int, target_attribute_id: StringName, operation: Operation, magnitude: float, source_id: StringName, owning_effect_handle: int = 0, priority: int = 0, creation_index: int = 0) -> void:
	_handle_id = handle_id
	_target_attribute_id = target_attribute_id
	_operation = operation
	_magnitude = magnitude
	_source_id = source_id
	_owning_effect_handle = owning_effect_handle
	_priority = priority
	_creation_index = creation_index

# ====== PUBLIC ========
## Returns the runtime handle used to identify this modifier.
func get_handle_id() -> int: return _handle_id
## Returns the attribute ID affected by this modifier.
func get_target_attribute_id() -> StringName: return _target_attribute_id
## Returns the additive or increase operation.
func get_operation() -> Operation: return _operation
## Returns the current modifier magnitude.
func get_magnitude() -> float: return _magnitude
## Replaces the magnitude while preserving modifier identity.
func set_magnitude(value: float) -> void: _magnitude = value
## Returns the stable source definition or source group ID.
func get_source_id() -> StringName: return _source_id
## Returns the owning active-effect handle, or [code]0[/code] when unowned.
func get_owning_effect_handle() -> int: return _owning_effect_handle
## Returns the deterministic processing priority.
func get_priority() -> int: return _priority
## Returns the creation index used as the final deterministic sort key.
func get_creation_index() -> int: return _creation_index
## Returns whether the modifier can still participate in calculations.
func is_valid() -> bool: return _valid
## Invalidates the modifier without applying reverse arithmetic.
func invalidate() -> void: _valid = false
