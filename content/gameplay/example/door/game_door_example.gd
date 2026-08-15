extends AnimatableBody3D
class_name GameDoorExample

signal door_opened()
signal door_closed()
signal door_locked_changed(locked: bool)

# ======== EXPORT =========
@export var kernel: GameObjectKernel = null
@export var door_visual: Node3D = null
@export var interaction_target: GameInteractionTarget = null
@export_range(0.0, 170.0, 1.0) var open_angle_degrees: float = 95.0
@export var starts_locked: bool = false

# ======== PRIVATE VAR ======
var _is_open: bool = false
var _is_locked: bool = false

# ======= OVERRIDE =======
func _ready() -> void:
	_is_locked = starts_locked
	_refresh_visual()
	_refresh_offers()

# ====== HELPERS ========
func _refresh_visual() -> void:
	if door_visual != null:
		door_visual.rotation_degrees.y = open_angle_degrees if _is_open else 0.0

func _refresh_offers() -> void:
	if interaction_target == null or kernel == null or kernel.get_object_context() == null:
		return
	var target_handle: GameObjectHandle = kernel.get_object_context().get_object_handle()
	var offers: Array[GameInteractionOffer] = []
	if _is_locked:
		var unlock_offer := GameInteractionOffer.new(&"example.door.unlock", &"verb.unlock", target_handle)
		unlock_offer.set_command_id(&"example.command.door.unlock")
		unlock_offer.set_priority(100)
		offers.append(unlock_offer)
	elif _is_open:
		var close_offer := GameInteractionOffer.new(&"example.door.close", &"verb.close", target_handle)
		close_offer.set_command_id(&"example.command.door.close")
		close_offer.set_priority(50)
		offers.append(close_offer)
	else:
		var open_offer := GameInteractionOffer.new(&"example.door.open", &"verb.open", target_handle)
		open_offer.set_command_id(&"example.command.door.open")
		open_offer.set_priority(50)
		offers.append(open_offer)
	interaction_target.offer_templates = offers

# ====== PUBLIC ========
func is_open() -> bool:
	return _is_open

func is_locked() -> bool:
	return _is_locked

func open_door() -> GameCommandResult:
	if _is_locked:
		return GameCommandResult.rejected_temporary(&"door_locked", "The example door is locked.")
	if _is_open:
		return GameCommandResult.success_unchanged(&"door_already_open")
	_is_open = true
	_refresh_visual()
	_refresh_offers()
	door_opened.emit()
	return GameCommandResult.success_changed(&"door_opened")

func close_door() -> GameCommandResult:
	if not _is_open:
		return GameCommandResult.success_unchanged(&"door_already_closed")
	_is_open = false
	_refresh_visual()
	_refresh_offers()
	door_closed.emit()
	return GameCommandResult.success_changed(&"door_closed")

func set_locked(value: bool) -> GameCommandResult:
	if _is_locked == value:
		return GameCommandResult.success_unchanged(&"door_lock_unchanged")
	_is_locked = value
	if _is_locked:
		_is_open = false
	_refresh_visual()
	_refresh_offers()
	door_locked_changed.emit(_is_locked)
	return GameCommandResult.success_changed(&"door_lock_changed", _is_locked)
