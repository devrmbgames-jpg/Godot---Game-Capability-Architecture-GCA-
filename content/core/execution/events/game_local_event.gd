extends RefCounted
class_name GameLocalEvent

# ======== PRIVATE VAR ======
var _event_type_id: StringName = &""
var _source_handle: GameObjectHandle = null
var _execution_context: GameExecutionContext = null
var _payload: Variant = null
var _sequence: int = 0

# ======= OVERRIDE =======
func _init(
    event_type_id: StringName = &"",
    source_handle: GameObjectHandle = null,
    execution_context: GameExecutionContext = null,
    payload: Variant = null
) -> void:
    _event_type_id = event_type_id
    _source_handle = source_handle
    _execution_context = execution_context
    _payload = payload

# ====== PUBLIC ========
func get_event_type_id() -> StringName:
    return _event_type_id

func get_source_handle() -> GameObjectHandle:
    return _source_handle

func get_execution_context() -> GameExecutionContext:
    return _execution_context

func get_payload() -> Variant:
    return _payload

func set_sequence(sequence: int) -> void:
    _sequence = sequence

func get_sequence() -> int:
    return _sequence

func to_dictionary() -> Dictionary:
    return {
        "event_type_id": _event_type_id,
        "sequence": _sequence,
        "payload": _payload,
        "execution_context": _execution_context.to_dictionary() if _execution_context != null else {},
    }
