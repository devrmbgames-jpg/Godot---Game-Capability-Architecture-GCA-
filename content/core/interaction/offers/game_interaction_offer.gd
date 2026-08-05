extends Resource
class_name GameInteractionOffer

# ======== PRIVATE VAR ======
var _offer_id: StringName = &""
var _verb_id: StringName = &""
var _target_handle: GameObjectHandle = null
var _priority: int = 0
var _ability_id: StringName = &""
var _command_id: StringName = &""
var _reservation_required: bool = false
var _hold_duration: float = 0.0
var _metadata: Dictionary = {}

# ======= OVERRIDE =======
func _init(offer_id: StringName = &"", verb_id: StringName = &"", target_handle: GameObjectHandle = null) -> void:
	_offer_id = offer_id
	_verb_id = verb_id
	_target_handle = target_handle

# ====== PUBLIC ========
func set_priority(value: int) -> void: _priority = value
func set_ability_id(value: StringName) -> void: _ability_id = value
func set_command_id(value: StringName) -> void: _command_id = value
func set_reservation_required(value: bool) -> void: _reservation_required = value
func set_hold_duration(value: float) -> void: _hold_duration = maxf(value, 0.0)
func set_metadata(value: Dictionary) -> void: _metadata = value.duplicate(true)
func get_offer_id() -> StringName: return _offer_id
func get_verb_id() -> StringName: return _verb_id
func get_target_handle() -> GameObjectHandle: return _target_handle
func get_priority() -> int: return _priority
func get_ability_id() -> StringName: return _ability_id
func get_command_id() -> StringName: return _command_id
func requires_reservation() -> bool: return _reservation_required
func get_hold_duration() -> float: return _hold_duration
func get_metadata() -> Dictionary: return _metadata.duplicate(true)
func is_valid() -> bool:
	return not _offer_id.is_empty() and not _verb_id.is_empty() and _target_handle != null and (not _ability_id.is_empty() or not _command_id.is_empty())
func to_dictionary() -> Dictionary:
	return {"offer_id": _offer_id, "verb_id": _verb_id, "priority": _priority, "ability_id": _ability_id, "command_id": _command_id, "reservation_required": _reservation_required, "hold_duration": _hold_duration, "metadata": _metadata.duplicate(true)}
