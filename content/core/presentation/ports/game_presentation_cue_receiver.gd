@tool
extends GameFeature
## Presentation port that receives cue requests from gameplay systems.
##
## Tracks looping cues by ownership key, emits adapter-facing signals, and cleans
## up owned cues on execution completion or feature shutdown.
class_name GamePresentationCueReceiver

## Emitted for valid start, update, and one-shot cue requests.
signal cue_requested(request: GamePresentationCueRequest)
## Emitted when a looping cue ownership key is stopped.
signal cue_stopped(ownership_key: StringName)

# ======== PRIVATE VAR ======
var _active_cues: Dictionary = {}

# ======= OVERRIDE =======
## Configures the presentation-cue receiver capability.
func _init() -> void:
	feature_id = &"object.presentation_cue_receiver"
	if provided_capabilities.is_empty():
		var spec := GameCapabilitySpec.new()
		spec.capability_id = GameCapabilityIds.PRESENTATION_CUE_RECEIVER
		provided_capabilities.append(spec)

## Stops every active looping cue during shutdown.
func on_game_shutdown() -> void:
	var keys: Array[StringName] = []
	for key: StringName in _active_cues.keys(): keys.append(key)
	for key: StringName in keys: stop_owned_cue(key)
	_active_cues.clear()

# ====== PUBLIC ========
## Validates and accepts a cue request, updating ownership for looping cues.
func request_cue(request: GamePresentationCueRequest) -> GameCommandResult:
	if request == null or not request.is_valid(): return GameCommandResult.configuration_error(&"invalid_presentation_cue", "Presentation cue request is invalid.")
	match request.get_action():
		GamePresentationCueRequest.Action.START, GamePresentationCueRequest.Action.UPDATE:
			if request.get_ownership_key().is_empty(): return GameCommandResult.configuration_error(&"missing_cue_ownership", "Looping cue requires ownership key.")
			_active_cues[request.get_ownership_key()] = request
		GamePresentationCueRequest.Action.STOP:
			return stop_owned_cue(request.get_ownership_key())
	cue_requested.emit(request)
	return GameCommandResult.success_changed(&"presentation_cue_requested")

## Stops one looping cue by ownership key.
func stop_owned_cue(ownership_key: StringName) -> GameCommandResult:
	if ownership_key.is_empty() or not _active_cues.has(ownership_key): return GameCommandResult.success_unchanged(&"presentation_cue_not_active")
	_active_cues.erase(ownership_key)
	cue_stopped.emit(ownership_key)
	return GameCommandResult.success_changed(&"presentation_cue_stopped")

## Stops every active cue associated with [param execution_id].
## Returns the number of cues stopped.
func stop_cues_by_execution(execution_id: int) -> int:
	var keys: Array[StringName] = []
	for key: StringName in _active_cues.keys():
		if (_active_cues[key] as GamePresentationCueRequest).get_execution_id() == execution_id: keys.append(key)
	for key: StringName in keys: stop_owned_cue(key)
	return keys.size()

## Returns active cue state keyed by ownership key.
func get_debug_snapshot() -> Dictionary:
	var cues: Dictionary = {}
	for key: StringName in _active_cues.keys(): cues[key] = (_active_cues[key] as GamePresentationCueRequest).to_dictionary()
	return {"active_cues": cues}
