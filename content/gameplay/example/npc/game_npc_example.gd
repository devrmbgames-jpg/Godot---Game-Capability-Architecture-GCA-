extends CharacterBody3D
class_name GameNPCExample

signal npc_offer_state_changed(available: bool)

# ======== EXPORT =========
@export var kernel: GameObjectKernel = null
@export var interaction_target: GameInteractionTarget = null
@export var scripted_control_source: GameScriptedControlSource = null
@export var control_arbiter: GameControlArbiter = null
@export var control_endpoint: GameControlEndpoint = null

# ======== PRIVATE VAR ======
var _dialogue_available: bool = true
var _control_attached: bool = false

# ======= OVERRIDE =======
func _ready() -> void:
	_attach_scripted_control()
	_refresh_offers()

# ====== HELPERS ========
func _attach_scripted_control() -> void:
	if scripted_control_source == null or control_arbiter == null or control_endpoint == null:
		return
	_control_attached = scripted_control_source.attach(control_endpoint, control_arbiter).is_success()

func _refresh_offers() -> void:
	if interaction_target == null or kernel == null or kernel.get_object_context() == null:
		return
	var offers: Array[GameInteractionOffer] = []
	if _dialogue_available:
		var offer := GameInteractionOffer.new(&"example.npc.talk", &"verb.talk", kernel.get_object_context().get_object_handle())
		offer.set_command_id(&"example.command.dialogue.start")
		offer.set_priority(100)
		offers.append(offer)
	interaction_target.offer_templates = offers

# ====== PUBLIC ========
func set_dialogue_available(value: bool) -> void:
	if _dialogue_available == value:
		return
	_dialogue_available = value
	_refresh_offers()
	npc_offer_state_changed.emit(_dialogue_available)

func is_dialogue_available() -> bool:
	return _dialogue_available

func has_scripted_control() -> bool:
	return _control_attached
