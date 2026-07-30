extends RefCounted
class_name GameActiveEffect

# ======== PRIVATE VAR ======
var _handle_id: int = 0
var _definition: GameEffectDefinition = null
var _source_handle: GameObjectHandle = null
var _instigator_handle: GameObjectHandle = null
var _remaining: float = 0.0
var _next_tick: float = 0.0
var _stacks: int = 1
var _modifier_handles: Array[int] = []
var _tag_handles: Array[GameTagSourceHandle] = []
var _root_operation_id: int = 0

# ======= OVERRIDE =======
func _init(handle_id: int, definition: GameEffectDefinition, source_handle: GameObjectHandle, instigator_handle: GameObjectHandle, root_operation_id: int) -> void:
	_handle_id = handle_id
	_definition = definition
	_source_handle = source_handle
	_instigator_handle = instigator_handle
	_root_operation_id = root_operation_id
	_remaining = definition.duration
	_next_tick = 0.0 if definition.execute_period_on_apply else definition.period

# ====== PUBLIC ========
func get_handle_id() -> int: return _handle_id
func get_definition() -> GameEffectDefinition: return _definition
func get_remaining() -> float: return _remaining
func get_stacks() -> int: return _stacks
func add_stack() -> bool:
	if _stacks >= _definition.stack_limit: return false
	_stacks += 1
	return true
func refresh_duration() -> void: _remaining = _definition.duration
func advance(delta: float) -> int:
	if _definition.duration_policy == GameEffectDefinition.DurationPolicy.DURATION: _remaining -= delta
	if _definition.period <= 0.0: return 0
	_next_tick -= delta
	var ticks: int = 0
	while _next_tick <= 0.0 and ticks < 32:
		ticks += 1
		_next_tick += _definition.period
	return ticks
func is_expired() -> bool: return _definition.duration_policy == GameEffectDefinition.DurationPolicy.DURATION and _remaining <= 0.0
func add_modifier_handle(handle_id: int) -> void: _modifier_handles.append(handle_id)
func get_modifier_handles() -> Array[int]: return _modifier_handles.duplicate()
func add_tag_handle(handle: GameTagSourceHandle) -> void: _tag_handles.append(handle)
func get_tag_handles() -> Array[GameTagSourceHandle]: return _tag_handles.duplicate()
func to_dictionary() -> Dictionary:
	return {"handle_id": _handle_id, "effect_id": _definition.effect_id, "remaining": _remaining, "stacks": _stacks, "root_operation_id": _root_operation_id}
