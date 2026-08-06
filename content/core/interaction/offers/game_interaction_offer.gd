extends Resource
## Runtime interaction action offered by a target to a source.
##
## Combines UI/AI verb metadata with target identity, priority, reservation and
## hold policies, plus the ability or command that performs the actual gameplay.
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
## Creates an offer identified by semantic offer/verb IDs and a target handle.
func _init(offer_id: StringName = &"", verb_id: StringName = &"", target_handle: GameObjectHandle = null) -> void:
	_offer_id = offer_id
	_verb_id = verb_id
	_target_handle = target_handle

# ====== PUBLIC ========
## Sets designer sorting priority.
func set_priority(value: int) -> void: _priority = value
## Selects an ability-based execution mode.
func set_ability_id(value: StringName) -> void: _ability_id = value
## Selects a command-based execution mode.
func set_command_id(value: StringName) -> void: _command_id = value
## Sets whether target reservation is required before execution.
func set_reservation_required(value: bool) -> void: _reservation_required = value
## Sets a non-negative hold/channel duration.
func set_hold_duration(value: float) -> void: _hold_duration = maxf(value, 0.0)
## Stores a deep copy of presentation and query metadata.
func set_metadata(value: Dictionary) -> void: _metadata = value.duplicate(true)
## Returns the target-local offer ID.
func get_offer_id() -> StringName: return _offer_id
## Returns the semantic verb ID used by UI and AI.
func get_verb_id() -> StringName: return _verb_id
## Returns the object providing this offer.
func get_target_handle() -> GameObjectHandle: return _target_handle
## Returns designer sorting priority.
func get_priority() -> int: return _priority
## Returns the ability ID used for execution, when configured.
func get_ability_id() -> StringName: return _ability_id
## Returns the command ID used for execution, when configured.
func get_command_id() -> StringName: return _command_id
## Returns whether execution must acquire a reservation.
func requires_reservation() -> bool: return _reservation_required
## Returns required hold duration.
func get_hold_duration() -> float: return _hold_duration
## Returns a deep copy of offer metadata.
func get_metadata() -> Dictionary: return _metadata.duplicate(true)
## Returns whether identity, target, and execution mode are configured.
func is_valid() -> bool:
	return not _offer_id.is_empty() and not _verb_id.is_empty() and _target_handle != null and (not _ability_id.is_empty() or not _command_id.is_empty())
## Serializes offer data for UI, AI, and diagnostics.
func to_dictionary() -> Dictionary:
	return {"offer_id": _offer_id, "verb_id": _verb_id, "priority": _priority, "ability_id": _ability_id, "command_id": _command_id, "reservation_required": _reservation_required, "hold_duration": _hold_duration, "metadata": _metadata.duplicate(true)}
