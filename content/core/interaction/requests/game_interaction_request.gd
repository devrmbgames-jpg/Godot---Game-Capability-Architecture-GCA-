extends RefCounted
## Normalized request for one semantic interaction attempt.
##
## Carries the interacting source, target, optional semantic intent or exact offer,
## causal execution context, and interaction-specific payload. Empty intent/offer means
## "perform the target's default currently available interaction".
class_name GameInteractionRequest

# ======= CONSTS =========
const ACTIVATION_INTENT_KEY: StringName = &"interaction_intent_id"
const ACTIVATION_PAYLOAD_KEY: StringName = &"interaction_payload"

# ======== PRIVATE VAR ======
var _source_handle: GameObjectHandle = null
var _target_handle: GameObjectHandle = null
var _intent_id: StringName = &""
var _offer_id: StringName = &""
var _execution_context: GameExecutionContext = null
var _payload: Dictionary = {}

# ======= OVERRIDE =======
func _init(
	source_handle: GameObjectHandle = null,
	target_handle: GameObjectHandle = null,
	intent_id: StringName = &"",
	execution_context: GameExecutionContext = null
) -> void:
	_source_handle = source_handle
	_target_handle = target_handle
	_intent_id = intent_id
	_execution_context = execution_context

# ====== PUBLIC ========
func set_offer_id(value: StringName) -> void:
	_offer_id = value

func set_payload(value: Dictionary) -> void:
	_payload = value.duplicate(true)

func get_source_handle() -> GameObjectHandle:
	return _source_handle

func get_target_handle() -> GameObjectHandle:
	return _target_handle

func get_intent_id() -> StringName:
	return _intent_id

func get_offer_id() -> StringName:
	return _offer_id

func get_execution_context() -> GameExecutionContext:
	return _execution_context

func get_payload() -> Dictionary:
	return _payload.duplicate(true)

func is_valid() -> bool:
	return (
		_source_handle != null
		and _target_handle != null
		and _execution_context != null
	)

func to_dictionary() -> Dictionary:
	return {
		"source": _source_handle.to_dictionary() if _source_handle != null else {},
		"target": _target_handle.to_dictionary() if _target_handle != null else {},
		"intent_id": _intent_id,
		"offer_id": _offer_id,
		"payload": _payload.duplicate(true),
	}
