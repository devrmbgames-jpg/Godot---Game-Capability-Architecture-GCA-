extends StaticBody3D
class_name GameChestExample

signal chest_opened()
signal chest_closed()
signal item_taken(item_id: StringName, remaining: int)

# ======== EXPORT =========
@export var kernel: GameObjectKernel = null
@export var lid_visual: Node3D = null
@export var interaction_target: GameInteractionTarget = null
@export var initial_items: Dictionary = {&"example.item.apple": 3, &"example.item.key": 1}

# ======== PRIVATE VAR ======
var _is_open: bool = false
var _items: Dictionary = {}

# ======= OVERRIDE =======
func _ready() -> void:
	_items = initial_items.duplicate(true)
	_refresh_visual()
	_refresh_offers()

# ====== HELPERS ========
func _refresh_visual() -> void:
	if lid_visual != null:
		lid_visual.rotation_degrees.x = -55.0 if _is_open else 0.0

func _refresh_offers() -> void:
	if interaction_target == null or kernel == null or kernel.get_object_context() == null:
		return
	var target_handle: GameObjectHandle = kernel.get_object_context().get_object_handle()
	var offer_id: StringName = &"example.chest.close" if _is_open else &"example.chest.open"
	var verb_id: StringName = &"verb.close" if _is_open else &"verb.open"
	var command_id: StringName = &"example.command.chest.close" if _is_open else &"example.command.chest.open"
	var offer := GameInteractionOffer.new(offer_id, verb_id, target_handle)
	offer.set_command_id(command_id)
	offer.set_reservation_required(true)
	offer.set_priority(50)
	interaction_target.offer_templates = [offer]

# ====== PUBLIC ========
func is_open() -> bool:
	return _is_open

func open_chest() -> GameCommandResult:
	if _is_open:
		return GameCommandResult.success_unchanged(&"chest_already_open")
	_is_open = true
	_refresh_visual()
	_refresh_offers()
	chest_opened.emit()
	return GameCommandResult.success_changed(&"chest_opened", get_inventory_snapshot())

func close_chest() -> GameCommandResult:
	if not _is_open:
		return GameCommandResult.success_unchanged(&"chest_already_closed")
	_is_open = false
	_refresh_visual()
	_refresh_offers()
	chest_closed.emit()
	return GameCommandResult.success_changed(&"chest_closed")

func take_item(item_id: StringName, amount: int = 1) -> GameCommandResult:
	if not _is_open:
		return GameCommandResult.rejected_temporary(&"chest_closed", "Open the example chest first.")
	if amount <= 0:
		return GameCommandResult.configuration_error(&"invalid_take_amount", "Item amount must be positive.")
	var current: int = int(_items.get(item_id, 0))
	if current < amount:
		return GameCommandResult.rejected_temporary(&"item_unavailable", "The requested item amount is unavailable.")
	var remaining: int = current - amount
	if remaining == 0:
		_items.erase(item_id)
	else:
		_items[item_id] = remaining
	item_taken.emit(item_id, remaining)
	return GameCommandResult.success_changed(&"chest_item_taken", {"item_id": item_id, "remaining": remaining})

func get_inventory_snapshot() -> Dictionary:
	return _items.duplicate(true)
