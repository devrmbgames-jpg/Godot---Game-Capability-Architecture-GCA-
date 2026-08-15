extends RefCounted
## Normalized control intent produced by a player, AI, or scripted source.
##
## Carries source and channel ownership identity, deterministic ordering data,
## execution context, typed-by-convention payload, and one-shot/continuous policy.
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
## Creates an intent and deep-copies its payload.
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
## Sets the source-local deterministic sequence number.
func set_sequence(value: int) -> void: _sequence = value
## Sets the simulation step at which the intent was produced.
func set_simulation_step(value: int) -> void: _simulation_step = value
## Sets intent priority metadata.
func set_priority(value: int) -> void: _priority = value
## Returns the semantic intent type.
func get_intent_type() -> StringName: return _intent_type
## Returns the producing control source ID.
func get_source_id() -> StringName: return _source_id
## Returns the controlled object handle.
func get_owner_handle() -> GameObjectHandle: return _owner_handle
## Returns the requested control channel.
func get_channel_id() -> StringName: return _channel_id
## Returns the source-local sequence number.
func get_sequence() -> int: return _sequence
## Returns the production simulation step.
func get_simulation_step() -> int: return _simulation_step
## Returns intent priority metadata.
func get_priority() -> int: return _priority
## Returns the causal execution context.
func get_execution_context() -> GameExecutionContext: return _execution_context
## Returns a deep copy of the normalized payload.
func get_payload() -> Dictionary: return _payload.duplicate(true)
## Returns whether the endpoint should retain this intent until cleared.
func is_continuous() -> bool: return _consume_policy == ConsumePolicy.CONTINUOUS
## Returns whether type, source, channel, and context are valid.
func is_valid() -> bool:
	return not _intent_type.is_empty() and not _source_id.is_empty() and GameControlChannels.is_known(_channel_id) and _execution_context != null
## Serializes intent diagnostics without exposing mutable payload state.
func to_dictionary() -> Dictionary:
	return {"intent_type": _intent_type, "source_id": _source_id, "channel": _channel_id, "sequence": _sequence, "simulation_step": _simulation_step, "priority": _priority, "payload": _payload.duplicate(true), "continuous": is_continuous()}
