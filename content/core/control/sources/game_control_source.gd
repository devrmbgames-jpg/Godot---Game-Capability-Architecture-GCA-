@tool
extends Node
class_name GameControlSource

signal ownership_changed(channel_id: StringName, owned: bool)
signal intent_produced(intent: GameControlIntent)

# ======== EXPORT =========
@export var source_id: StringName = &""
@export var requested_channels: Array[StringName] = []
@export var priority: int = 0

# ======== PRIVATE VAR ======
var _endpoint: GameControlEndpoint = null
var _arbiter: GameControlArbiter = null
var _owned_channels: Dictionary = {}
var _suspended: bool = false
var _sequence: int = 0

# ======= OVERRIDE =======
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if source_id.is_empty(): warnings.append("GameControlSource requires source_id.")
	if requested_channels.is_empty(): warnings.append("GameControlSource has no requested channels.")
	for channel_id: StringName in requested_channels:
		if not GameControlChannels.is_known(channel_id): warnings.append("Unknown control channel '%s'." % channel_id)
	return warnings

# ====== PUBLIC ========
func attach(endpoint: GameControlEndpoint, arbiter: GameControlArbiter) -> GameCommandResult:
	if endpoint == null or arbiter == null: return GameCommandResult.configuration_error(&"missing_control_pipeline", "Control source requires endpoint and arbiter.")
	_endpoint = endpoint
	_arbiter = arbiter
	return arbiter.register_source(self)

func detach() -> void:
	if _arbiter != null: _arbiter.unregister_source(source_id)
	_endpoint = null
	_arbiter = null
	_owned_channels.clear()

func request_control() -> Dictionary:
	var results: Dictionary = {}
	if _arbiter == null: return results
	for channel_id: StringName in requested_channels:
		results[channel_id] = _arbiter.request_ownership(source_id, channel_id, priority)
	return results

func suspend() -> void: _suspended = true
func resume() -> void: _suspended = false
func is_suspended() -> bool: return _suspended
func owns_channel(channel_id: StringName) -> bool: return bool(_owned_channels.get(channel_id, false))

func notify_ownership(channel_id: StringName, owned: bool) -> void:
	if owned: _owned_channels[channel_id] = true
	else: _owned_channels.erase(channel_id)
	ownership_changed.emit(channel_id, owned)

func submit_intent(intent_type: StringName, channel_id: StringName, execution_context: GameExecutionContext, payload: Dictionary = {}, continuous: bool = false) -> GameCommandResult:
	if _suspended: return GameCommandResult.rejected_temporary(&"source_suspended", "Control source is suspended.")
	if _endpoint == null: return GameCommandResult.invalid_target("Control endpoint is not attached.")
	_sequence += 1
	var policy: int = GameControlIntent.ConsumePolicy.CONTINUOUS if continuous else GameControlIntent.ConsumePolicy.ONE_SHOT
	var intent := GameControlIntent.new(intent_type, source_id, _endpoint.get_owner_handle(), channel_id, execution_context, payload, policy)
	intent.set_sequence(_sequence)
	intent.set_priority(priority)
	intent_produced.emit(intent)
	return _endpoint.receive_intent(intent)
