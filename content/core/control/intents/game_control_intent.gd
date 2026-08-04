extends RefCounted
class_name GameControlIntent

# ======= ENUMS =========
enum ConsumePolicy {
	ONE_SHOT,
	CONTINUOUS,
}

# ======== PRIVATE VAR ======
var _intent_type: StringName = &""
var _source_id: StringName = &""
var _owner_handle: GameObjectHandle = null
var _channel_id: StringName = &""
var _sequence: int = 0
var _simulation_step: int = 0
var _priority: int = 0
var _execution_context: GameExecutionContext = null
var _payload: Dictionary = {}
var _consume_policy: int = ConsumePolicy.ONE_SHOT

# ======= OVERRIDE =======
func _init(
	intent_type: StringName = &"",
	source_id: StringName = &"",
	owner_handle: GameObjectHandle = null,
	channel_id: StringName = &"",
	execution_context: GameExecutionContext = null,
	payload: Dictionary = {},
	consume_policy: int = ConsumePolicy.ONE_SHOT
) -> void:
	_intent_type = intent_type
	_source_id = source_id
	_owner_handle = owner_handle
	_channel_id = channel_id
	_execution_context = execution_context
	_payload = payload.duplicate(true)
	_consume_policy = consume_policy

# ====== PUBLIC ========
func set_sequence(value: int) -> void: _sequence = value
func set_simulation_step(value: int) -> void: _simulation_step = value
func set_priority(value: int) -> void: _priority = value
func get_intent_type() -> StringName: return _intent_type
func get_source_id() -> StringName: return _source_id
func get_owner_handle() -> GameObjectHandle: return _owner_handle
func get_channel_id() -> StringName: return _channel_id
func get_sequence() -> int: return _sequence
func get_simulation_step() -> int: return _simulation_step
func get_priority() -> int: return _priority
func get_execution_context() -> GameExecutionContext: return _execution_context
func get_payload() -> Dictionary: return _payload.duplicate(true)
func is_continuous() -> bool: return _consume_policy == ConsumePolicy.CONTINUOUS
func is_valid() -> bool:
	return not _intent_type.is_empty() and not _source_id.is_empty() and GameControlChannels.is_known(_channel_id) and _execution_context != null
func to_dictionary() -> Dictionary:
	return {"intent_type": _intent_type, "source_id": _source_id, "channel": _channel_id, "sequence": _sequence, "simulation_step": _simulation_step, "priority": _priority, "payload": _payload.duplicate(true), "continuous": is_continuous()}
