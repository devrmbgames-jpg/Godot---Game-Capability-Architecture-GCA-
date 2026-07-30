extends RefCounted
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
func get_handle_id() -> int: return _handle_id
func get_target_attribute_id() -> StringName: return _target_attribute_id
func get_operation() -> Operation: return _operation
func get_magnitude() -> float: return _magnitude
func set_magnitude(value: float) -> void: _magnitude = value
func get_source_id() -> StringName: return _source_id
func get_owning_effect_handle() -> int: return _owning_effect_handle
func get_priority() -> int: return _priority
func get_creation_index() -> int: return _creation_index
func is_valid() -> bool: return _valid
func invalidate() -> void: _valid = false
