extends RefCounted
class_name GameDamageRequest

# ======== PRIVATE VAR ======
var _source_handle: GameObjectHandle = null
var _instigator_handle: GameObjectHandle = null
var _target_handle: GameObjectHandle = null
var _base_amount: float = 0.0
var _damage_type_tags: Array[StringName] = []
var _execution_context: GameExecutionContext = null
var _flags: int = 0

# ======= OVERRIDE =======
func _init(source_handle: GameObjectHandle, instigator_handle: GameObjectHandle, target_handle: GameObjectHandle, base_amount: float, damage_type_tags: Array[StringName], execution_context: GameExecutionContext, flags: int = 0) -> void:
	_source_handle = source_handle
	_instigator_handle = instigator_handle
	_target_handle = target_handle
	_base_amount = base_amount
	_damage_type_tags = damage_type_tags.duplicate()
	_execution_context = execution_context
	_flags = flags

# ====== PUBLIC ========
func get_source_handle() -> GameObjectHandle: return _source_handle
func get_instigator_handle() -> GameObjectHandle: return _instigator_handle
func get_target_handle() -> GameObjectHandle: return _target_handle
func get_base_amount() -> float: return _base_amount
func get_damage_type_tags() -> Array[StringName]: return _damage_type_tags.duplicate()
func get_execution_context() -> GameExecutionContext: return _execution_context
func get_flags() -> int: return _flags
func is_valid() -> bool: return _target_handle != null and _target_handle.is_resolved() and _execution_context != null and _base_amount >= 0.0
