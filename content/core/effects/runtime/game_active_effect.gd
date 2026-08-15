extends RefCounted
## Runtime instance of one applied [GameEffectDefinition].
##
## Tracks duration, periodic scheduling, stacks, owned modifier/tag handles, and
## the root operation that caused the effect. It is intentionally not a Node.
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
## Creates runtime effect state and initializes its first scheduled tick.
func _init(handle_id: int, definition: GameEffectDefinition, source_handle: GameObjectHandle, instigator_handle: GameObjectHandle, root_operation_id: int) -> void:
	_handle_id = handle_id
	_definition = definition
	_source_handle = source_handle
	_instigator_handle = instigator_handle
	_root_operation_id = root_operation_id
	_remaining = definition.duration
	_next_tick = 0.0 if definition.execute_period_on_apply else definition.period

# ====== PUBLIC ========
## Returns the active-effect runtime handle.
func get_handle_id() -> int: return _handle_id
## Returns the immutable effect definition.
func get_definition() -> GameEffectDefinition: return _definition
## Returns the remaining duration in simulation seconds.
func get_remaining() -> float: return _remaining
## Returns the current stack count.
func get_stacks() -> int: return _stacks
## Adds one stack when below the definition limit.
func add_stack() -> bool:
	if _stacks >= _definition.stack_limit: return false
	_stacks += 1
	return true
## Resets remaining duration to the configured definition duration.
func refresh_duration() -> void: _remaining = _definition.duration
## Advances duration and periodic scheduling by [param delta].
## Returns the number of due ticks, capped to protect one update from runaway work.
func advance(delta: float) -> int:
	if _definition.duration_policy == GameEffectDefinition.DurationPolicy.DURATION: _remaining -= delta
	if _definition.period <= 0.0: return 0
	_next_tick -= delta
	var ticks: int = 0
	while _next_tick <= 0.0 and ticks < 32:
		ticks += 1
		_next_tick += _definition.period
	return ticks
## Returns whether a duration effect has reached zero remaining time.
func is_expired() -> bool: return _definition.duration_policy == GameEffectDefinition.DurationPolicy.DURATION and _remaining <= 0.0
## Registers a modifier handle owned by this effect.
func add_modifier_handle(handle_id: int) -> void: _modifier_handles.append(handle_id)
## Returns a copy of owned modifier handles.
func get_modifier_handles() -> Array[int]: return _modifier_handles.duplicate()
## Registers a tag-source handle owned by this effect.
func add_tag_handle(handle: GameTagSourceHandle) -> void: _tag_handles.append(handle)
## Returns a copy of owned tag-source handles.
func get_tag_handles() -> Array[GameTagSourceHandle]: return _tag_handles.duplicate()
## Serializes diagnostic runtime state without exposing mutable collections.
func to_dictionary() -> Dictionary:
	return {"handle_id": _handle_id, "effect_id": _definition.effect_id, "remaining": _remaining, "stacks": _stacks, "root_operation_id": _root_operation_id}
