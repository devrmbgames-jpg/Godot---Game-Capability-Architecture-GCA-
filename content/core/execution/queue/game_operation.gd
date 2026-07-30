extends RefCounted
class_name GameOperation

# ======== PRIVATE VAR ======
var _operation_type: StringName = &""
var _source_definition_id: StringName = &""
var _target_handle: GameObjectHandle = null
var _trigger_key: StringName = &""
var _execution_context: GameExecutionContext = null
var _debug_label: String = ""
var _sequence: int = 0

# ======= OVERRIDE =======
func _init(
    operation_type: StringName = &"",
    execution_context: GameExecutionContext = null,
    source_definition_id: StringName = &"",
    target_handle: GameObjectHandle = null,
    trigger_key: StringName = &"",
    debug_label: String = ""
) -> void:
    _operation_type = operation_type
    _execution_context = execution_context
    _source_definition_id = source_definition_id
    _target_handle = target_handle
    _trigger_key = trigger_key
    _debug_label = debug_label

# ====== PUBLIC ========
func execute(_context: GameExecutionContext) -> GameCommandResult:
    return GameCommandResult.success_unchanged(&"operation_noop")

func cancel(_reason: StringName) -> void:
    pass

func set_sequence(sequence: int) -> void:
    _sequence = sequence

func get_sequence() -> int:
    return _sequence

func get_operation_type() -> StringName:
    return _operation_type

func get_source_definition_id() -> StringName:
    return _source_definition_id

func get_target_handle() -> GameObjectHandle:
    return _target_handle

func get_trigger_key() -> StringName:
    return _trigger_key

func get_execution_context() -> GameExecutionContext:
    return _execution_context

func get_debug_label() -> String:
    return _debug_label

func get_guard_key() -> String:
    var target_id: String = "none"
    if _target_handle != null:
        target_id = str(_target_handle.get_stable_id())
        if target_id.is_empty():
            target_id = str(_target_handle.get_runtime_instance_id())
    return "%s|%s|%s|%s" % [_operation_type, _source_definition_id, target_id, _trigger_key]
