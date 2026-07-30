extends RefCounted
class_name GameCommand

# ======== PRIVATE VAR ======
var _command_type_id: StringName = &""
var _sender_handle: GameObjectHandle = null
var _target_handle: GameObjectHandle = null
var _execution_context: GameExecutionContext = null
var _payload: Variant = null
var _flags: int = 0
var _correlation_id: StringName = &""
var _required_capability_id: StringName = &""

# ======= OVERRIDE =======
func _init(
    command_type_id: StringName = &"",
    sender_handle: GameObjectHandle = null,
    target_handle: GameObjectHandle = null,
    execution_context: GameExecutionContext = null,
    payload: Variant = null,
    required_capability_id: StringName = &"",
    flags: int = 0,
    correlation_id: StringName = &""
) -> void:
    _command_type_id = command_type_id
    _sender_handle = sender_handle
    _target_handle = target_handle
    _execution_context = execution_context
    _payload = payload
    _required_capability_id = required_capability_id
    _flags = flags
    _correlation_id = correlation_id

# ====== PUBLIC ========
func get_command_type_id() -> StringName:
    return _command_type_id

func get_sender_handle() -> GameObjectHandle:
    return _sender_handle

func get_target_handle() -> GameObjectHandle:
    return _target_handle

func get_execution_context() -> GameExecutionContext:
    return _execution_context

func get_payload() -> Variant:
    return _payload

func get_flags() -> int:
    return _flags

func get_correlation_id() -> StringName:
    return _correlation_id

func get_required_capability_id() -> StringName:
    return _required_capability_id
