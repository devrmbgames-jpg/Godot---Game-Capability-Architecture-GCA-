extends RefCounted
## Presentation-layer request emitted by gameplay systems.
##
## Describes a cue action and participants without exposing AnimationTree, audio,
## VFX, or camera implementation details to gameplay code.
class_name GamePresentationCueRequest

# ======= ENUMS =========
enum Action {
	START,
	STOP,
	UPDATE,
	ONE_SHOT,
}

# ======== PRIVATE VAR ======
var _cue_id: StringName = &""
var _action: int = Action.ONE_SHOT
var _owner_handle: GameObjectHandle = null
var _source_handle: GameObjectHandle = null
var _target_handle: GameObjectHandle = null
var _execution_id: int = 0
var _context_tags: Array[StringName] = []
var _magnitude: float = 1.0
var _payload: Dictionary = {}
var _ownership_key: StringName = &""

# ======= OVERRIDE =======
## Creates a cue request for [param owner_handle].
func _init(cue_id: StringName = &"", action: int = Action.ONE_SHOT, owner_handle: GameObjectHandle = null) -> void:
	_cue_id = cue_id
	_action = action
	_owner_handle = owner_handle

# ====== PUBLIC ========
## Sets the gameplay source handle.
func set_source_handle(value: GameObjectHandle) -> void: _source_handle = value
## Sets the presentation target handle.
func set_target_handle(value: GameObjectHandle) -> void: _target_handle = value
## Associates the cue with an ability or operation execution ID.
func set_execution_id(value: int) -> void: _execution_id = value
## Stores a copy of contextual gameplay tags.
func set_context_tags(value: Array[StringName]) -> void: _context_tags = value.duplicate()
## Sets normalized or mechanic-specific cue magnitude.
func set_magnitude(value: float) -> void: _magnitude = value
## Stores a deep copy of adapter-specific presentation payload.
func set_payload(value: Dictionary) -> void: _payload = value.duplicate(true)
## Sets the lifecycle key used to own looping cues.
func set_ownership_key(value: StringName) -> void: _ownership_key = value
## Returns the stable cue ID.
func get_cue_id() -> StringName: return _cue_id
## Returns the requested start, stop, update, or one-shot action.
func get_action() -> int: return _action
## Returns the object that owns the cue.
func get_owner_handle() -> GameObjectHandle: return _owner_handle
## Returns the gameplay source handle.
func get_source_handle() -> GameObjectHandle: return _source_handle
## Returns the presentation target handle.
func get_target_handle() -> GameObjectHandle: return _target_handle
## Returns the associated execution ID.
func get_execution_id() -> int: return _execution_id
## Returns a copy of contextual tags.
func get_context_tags() -> Array[StringName]: return _context_tags.duplicate()
## Returns cue magnitude.
func get_magnitude() -> float: return _magnitude
## Returns a deep copy of presentation payload.
func get_payload() -> Dictionary: return _payload.duplicate(true)
## Returns the looping-cue ownership key.
func get_ownership_key() -> StringName: return _ownership_key
## Returns whether the request has a cue ID and owner.
func is_valid() -> bool: return not _cue_id.is_empty() and _owner_handle != null
## Serializes the cue request for adapters and diagnostics.
func to_dictionary() -> Dictionary:
	return {"cue_id": _cue_id, "action": _action, "execution_id": _execution_id, "context_tags": _context_tags.duplicate(), "magnitude": _magnitude, "payload": _payload.duplicate(true), "ownership_key": _ownership_key}
