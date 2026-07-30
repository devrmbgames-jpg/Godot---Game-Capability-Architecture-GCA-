extends RefCounted
class_name GameExecutionQueue

signal operation_enqueued(operation: GameOperation)
signal operation_completed(operation: GameOperation, result: GameCommandResult)
signal root_cancelled(root_operation_id: int, reason: StringName)

# ======= ENUMS =========
enum ErrorPolicy {
    CONTINUE,
    STOP_ROOT,
    STOP_ALL,
}

# ======== PRIVATE VAR ======
var _queue: Array[GameOperation] = []
var _sequence_counter: int = 0
var _max_depth: int = 16
var _max_operations_per_root: int = 128
var _max_repeats_per_guard: int = 4
var _error_policy: int = ErrorPolicy.CONTINUE
var _root_operation_counts: Dictionary = {}
var _root_guard_counts: Dictionary = {}
var _cancelled_roots: Dictionary = {}
var _cancelled_root_order: Array[int] = []
var _is_processing: bool = false
var _diagnostics: GameDiagnosticsSink = null

# ====== HELPERS ========
func _get_root_id(operation: GameOperation) -> int:
    var context: GameExecutionContext = operation.get_execution_context()
    if context == null:
        return 0
    return context.get_root_operation_id()

func _get_guard_count(root_id: int, guard_key: String) -> int:
    if not _root_guard_counts.has(root_id):
        return 0
    var guard_counts: Dictionary = _root_guard_counts[root_id]
    return guard_counts.get(guard_key, 0)

func _increment_guard(root_id: int, guard_key: String) -> void:
    var guard_counts: Dictionary = _root_guard_counts.get(root_id, {})
    guard_counts[guard_key] = guard_counts.get(guard_key, 0) + 1
    _root_guard_counts[root_id] = guard_counts

func _handle_operation_failure(operation: GameOperation, result: GameCommandResult) -> void:
    if result.is_success():
        return
    match _error_policy:
        ErrorPolicy.STOP_ROOT:
            cancel_root(_get_root_id(operation), &"operation_failed")
        ErrorPolicy.STOP_ALL:
            cancel_all(&"operation_failed")
        _:
            pass

func _finish_root_if_idle(root_id: int) -> void:
    for queued: GameOperation in _queue:
        if _get_root_id(queued) == root_id:
            return
    _root_operation_counts.erase(root_id)
    _root_guard_counts.erase(root_id)

# ====== PUBLIC ========
func configure(max_depth: int, max_operations_per_root: int, max_repeats_per_guard: int, error_policy: int) -> void:
    _max_depth = maxi(1, max_depth)
    _max_operations_per_root = maxi(1, max_operations_per_root)
    _max_repeats_per_guard = maxi(1, max_repeats_per_guard)
    _error_policy = error_policy

func set_diagnostics(diagnostics: GameDiagnosticsSink) -> void:
    _diagnostics = diagnostics

func enqueue(operation: GameOperation) -> GameCommandResult:
    if operation == null or operation.get_execution_context() == null:
        return GameCommandResult.configuration_error(&"invalid_operation", "Queued operation or its context is null.")

    var context: GameExecutionContext = operation.get_execution_context()
    var root_id: int = context.get_root_operation_id()
    if _cancelled_roots.has(root_id):
        return GameCommandResult.new(GameCommandResult.Status.CANCELLED, &"root_cancelled", "Root operation is cancelled.")
    if context.get_chain_depth() > _max_depth:
        if _diagnostics != null:
            _diagnostics.record(GameDiagnosticsSink.Level.ERROR, &"operation_depth_limit", "Operation depth limit exceeded.", context.to_dictionary())
        return GameCommandResult.new(GameCommandResult.Status.QUEUE_LIMIT, &"operation_depth_limit", "Operation depth limit exceeded.")

    var operation_count: int = _root_operation_counts.get(root_id, 0)
    if operation_count >= _max_operations_per_root:
        if _diagnostics != null:
            _diagnostics.record(GameDiagnosticsSink.Level.ERROR, &"operation_budget_exceeded", "Root operation budget exceeded.", context.to_dictionary())
        return GameCommandResult.new(GameCommandResult.Status.QUEUE_LIMIT, &"operation_budget_exceeded", "Root operation budget exceeded.")

    var guard_key: String = operation.get_guard_key()
    if _get_guard_count(root_id, guard_key) >= _max_repeats_per_guard:
        if _diagnostics != null:
            _diagnostics.record(GameDiagnosticsSink.Level.WARNING, &"operation_cycle_guard", "Operation cycle guard rejected a repeated operation.", {"guard_key": guard_key, "root_id": root_id})
        return GameCommandResult.new(GameCommandResult.Status.CYCLE_GUARD, &"operation_cycle_guard", "Operation cycle guard rejected a repeated operation.")

    _sequence_counter += 1
    operation.set_sequence(_sequence_counter)
    _queue.append(operation)
    _root_operation_counts[root_id] = operation_count + 1
    _increment_guard(root_id, guard_key)
    if _diagnostics != null:
        _diagnostics.trace_operation(operation, &"enqueued")
    operation_enqueued.emit(operation)
    return GameCommandResult.success_changed(&"operation_enqueued", operation)

func process(max_operations: int = -1) -> int:
    if _is_processing:
        return 0
    _is_processing = true
    var processed: int = 0
    while not _queue.is_empty() and (max_operations < 0 or processed < max_operations):
        var operation: GameOperation = _queue.pop_front()
        var root_id: int = _get_root_id(operation)
        if _cancelled_roots.has(root_id):
            operation.cancel(&"root_cancelled")
            _finish_root_if_idle(root_id)
            continue
        var result: GameCommandResult = operation.execute(operation.get_execution_context())
        result.attach_source_operation_id(operation.get_execution_context().get_operation_id())
        processed += 1
        if _diagnostics != null:
            _diagnostics.trace_operation(operation, &"completed", result)
        operation_completed.emit(operation, result)
        _handle_operation_failure(operation, result)
        _finish_root_if_idle(root_id)
    _is_processing = false
    return processed

func cancel_root(root_operation_id: int, reason: StringName = &"cancelled") -> void:
    if not _cancelled_roots.has(root_operation_id):
        _cancelled_root_order.append(root_operation_id)
    _cancelled_roots[root_operation_id] = reason
    while _cancelled_root_order.size() > 256:
        var expired_root_id: int = _cancelled_root_order.pop_front()
        _cancelled_roots.erase(expired_root_id)
    var retained: Array[GameOperation] = []
    for operation: GameOperation in _queue:
        if _get_root_id(operation) == root_operation_id:
            operation.cancel(reason)
        else:
            retained.append(operation)
    _queue = retained
    _finish_root_if_idle(root_operation_id)
    root_cancelled.emit(root_operation_id, reason)

func cancel_all(reason: StringName = &"cancelled") -> void:
    var roots: Array = _root_operation_counts.keys()
    for root_id: int in roots:
        cancel_root(root_id, reason)

func clear() -> void:
    cancel_all(&"queue_cleared")
    _queue.clear()
    _root_operation_counts.clear()
    _root_guard_counts.clear()
    _cancelled_roots.clear()
    _cancelled_root_order.clear()
    _is_processing = false

func is_processing() -> bool:
    return _is_processing

func get_pending_count() -> int:
    return _queue.size()

func get_debug_snapshot() -> Array[Dictionary]:
    var snapshot: Array[Dictionary] = []
    for operation: GameOperation in _queue:
        snapshot.append({
            "sequence": operation.get_sequence(),
            "operation_type": operation.get_operation_type(),
            "guard_key": operation.get_guard_key(),
            "context": operation.get_execution_context().to_dictionary(),
        })
    return snapshot
