@tool
extends GameFeature
class_name GameControlArbiter

signal channel_owner_changed(channel_id: StringName, previous_source_id: StringName, current_source_id: StringName)

# ======== PRIVATE VAR ======
var _sources: Dictionary = {}
var _owners: Dictionary = {}
var _priorities: Dictionary = {}
var _restore_stack: Dictionary = {}

# ======= OVERRIDE =======
func _init() -> void:
	feature_id = &"object.control_arbiter"
	if provided_capabilities.is_empty():
		var spec := GameCapabilitySpec.new()
		spec.capability_id = GameCapabilityIds.CONTROL_ARBITER
		provided_capabilities.append(spec)

func on_game_shutdown() -> void:
	for channel_id: StringName in _owners.keys():
		_notify_source(_owners[channel_id], channel_id, false)
	_sources.clear(); _owners.clear(); _priorities.clear(); _restore_stack.clear()

# ====== HELPERS ========
func _notify_source(source_id: StringName, channel_id: StringName, owned: bool) -> void:
	var source: GameControlSource = _sources.get(source_id) as GameControlSource
	if source != null: source.notify_ownership(channel_id, owned)

func _set_owner(channel_id: StringName, source_id: StringName, priority: int) -> void:
	var previous: StringName = _owners.get(channel_id, &"")
	if not previous.is_empty(): _notify_source(previous, channel_id, false)
	_owners[channel_id] = source_id
	_priorities[channel_id] = priority
	_notify_source(source_id, channel_id, true)
	channel_owner_changed.emit(channel_id, previous, source_id)

# ====== PUBLIC ========
func register_source(source: GameControlSource) -> GameCommandResult:
	if source == null or source.source_id.is_empty(): return GameCommandResult.configuration_error(&"invalid_control_source", "Control source is invalid.")
	if _sources.has(source.source_id): return GameCommandResult.configuration_error(&"duplicate_control_source", "Control source ID is duplicated.")
	_sources[source.source_id] = source
	return GameCommandResult.success_changed(&"control_source_registered")

func unregister_source(source_id: StringName) -> void:
	if not _sources.has(source_id): return
	var channels: Array[StringName] = []
	for channel_id: StringName in _owners.keys():
		if _owners[channel_id] == source_id: channels.append(channel_id)
	for channel_id: StringName in channels: release_ownership(source_id, channel_id)
	_sources.erase(source_id)

func request_ownership(source_id: StringName, channel_id: StringName, priority: int = 0, temporary_override: bool = false) -> GameCommandResult:
	if not _sources.has(source_id): return GameCommandResult.rejected_permanent(&"unknown_control_source", "Control source is not registered.")
	if not GameControlChannels.is_known(channel_id): return GameCommandResult.configuration_error(&"unknown_control_channel", "Unknown control channel '%s'." % channel_id)
	var current: StringName = _owners.get(channel_id, &"")
	if current == source_id: return GameCommandResult.success_unchanged(&"already_channel_owner")
	var current_priority: int = int(_priorities.get(channel_id, -2147483648))
	if not current.is_empty() and priority <= current_priority:
		return GameCommandResult.rejected_temporary(&"channel_occupied", "Control channel is owned by an equal or higher priority source.", {"owner": current})
	if temporary_override and not current.is_empty():
		var stack: Array[StringName] = _restore_stack.get(channel_id, [])
		stack.append(current)
		_restore_stack[channel_id] = stack
	_set_owner(channel_id, source_id, priority)
	return GameCommandResult.success_changed(&"channel_acquired")

func release_ownership(source_id: StringName, channel_id: StringName) -> GameCommandResult:
	if _owners.get(channel_id, &"") != source_id: return GameCommandResult.success_unchanged(&"channel_not_owned")
	_notify_source(source_id, channel_id, false)
	_owners.erase(channel_id); _priorities.erase(channel_id)
	var stack: Array[StringName] = _restore_stack.get(channel_id, [])
	while not stack.is_empty():
		var fallback: StringName = stack.pop_back()
		if _sources.has(fallback):
			_set_owner(channel_id, fallback, (_sources[fallback] as GameControlSource).priority)
			break
	_restore_stack[channel_id] = stack
	return GameCommandResult.success_changed(&"channel_released")

func owns_channel(source_id: StringName, channel_id: StringName) -> bool:
	return _owners.get(channel_id, &"") == source_id

func get_debug_snapshot() -> Dictionary:
	return {"sources": _sources.keys(), "owners": _owners.duplicate(), "priorities": _priorities.duplicate(), "restore_stack": _restore_stack.duplicate(true)}
