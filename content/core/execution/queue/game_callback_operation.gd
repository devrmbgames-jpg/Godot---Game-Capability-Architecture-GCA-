extends GameOperation
class_name GameCallbackOperation

# ======== PRIVATE VAR ======
var _callback: Callable = Callable()
var _cancel_callback: Callable = Callable()

# ======= OVERRIDE =======
func _init(
    operation_type: StringName = &"",
    execution_context: GameExecutionContext = null,
    callback: Callable = Callable(),
    source_definition_id: StringName = &"",
    target_handle: GameObjectHandle = null,
    trigger_key: StringName = &"",
    debug_label: String = "",
    cancel_callback: Callable = Callable()
) -> void:
    super(operation_type, execution_context, source_definition_id, target_handle, trigger_key, debug_label)
    _callback = callback
    _cancel_callback = cancel_callback

# ====== PUBLIC ========
func execute(context: GameExecutionContext) -> GameCommandResult:
    if not _callback.is_valid():
        return GameCommandResult.configuration_error(&"invalid_operation_callback", "Operation callback is invalid.")
    var value: Variant = _callback.call(context)
    if value is GameCommandResult:
        return value as GameCommandResult
    return GameCommandResult.success_changed(&"operation_callback_completed", value)

func cancel(reason: StringName) -> void:
    if _cancel_callback.is_valid():
        _cancel_callback.call(reason)
