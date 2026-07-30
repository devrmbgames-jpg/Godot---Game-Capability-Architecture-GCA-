extends RefCounted
class_name GameObjectContext

# ======== PRIVATE VAR ======
var _kernel_reference: WeakRef = null
var _root_reference: WeakRef = null
var _identity: GameObjectIdentity = null
var _object_handle: GameObjectHandle = null
var _capability_registry: GameCapabilityRegistry = null
var _tag_container: GameTagContainer = null
var _execution_queue: GameExecutionQueue = null
var _diagnostics: GameDiagnosticsSink = null
var _world_ports: Dictionary = {}
var _runtime_flags: Dictionary = {}

# ======= OVERRIDE =======
func _init(
    kernel: GameObjectKernel = null,
    object_root: Node = null,
    identity: GameObjectIdentity = null,
    object_handle: GameObjectHandle = null,
    capability_registry: GameCapabilityRegistry = null,
    tag_container: GameTagContainer = null,
    execution_queue: GameExecutionQueue = null,
    diagnostics: GameDiagnosticsSink = null,
    world_ports: Dictionary = {},
    runtime_flags: Dictionary = {}
) -> void:
    if kernel != null:
        _kernel_reference = weakref(kernel)
    if object_root != null:
        _root_reference = weakref(object_root)
    _identity = identity
    _object_handle = object_handle
    _capability_registry = capability_registry
    _tag_container = tag_container
    _execution_queue = execution_queue
    _diagnostics = diagnostics
    _world_ports = world_ports.duplicate()
    _runtime_flags = runtime_flags.duplicate(true)

# ====== PUBLIC ========
func get_kernel() -> GameObjectKernel:
    if _kernel_reference == null:
        return null
    return _kernel_reference.get_ref() as GameObjectKernel

func get_object_root() -> Node:
    if _root_reference == null:
        return null
    return _root_reference.get_ref() as Node

func get_identity() -> GameObjectIdentity:
    return _identity

func get_object_handle() -> GameObjectHandle:
    return _object_handle

func get_capability(capability_id: StringName) -> GameFeature:
    if _capability_registry == null:
        return null
    return _capability_registry.get_exclusive(capability_id)

func get_capabilities(capability_id: StringName) -> Array[GameFeature]:
    if _capability_registry == null:
        return []
    return _capability_registry.get_all(capability_id)

func has_exact_tag(tag_id: StringName) -> bool:
    return _tag_container != null and _tag_container.has_exact_tag(tag_id)

func has_tag_or_child(parent_tag_id: StringName) -> bool:
    return _tag_container != null and _tag_container.has_tag_or_child(parent_tag_id)

func dispatch_command(command: GameCommand) -> GameCommandResult:
    var kernel: GameObjectKernel = get_kernel()
    if kernel == null:
        return GameCommandResult.invalid_target("Context kernel is no longer resolved.")
    return kernel.dispatch_command(command)

func dispatch_query(query: GameQuery) -> GameQueryResult:
    var kernel: GameObjectKernel = get_kernel()
    if kernel == null:
        return GameQueryResult.invalid_target("Context kernel is no longer resolved.")
    return kernel.dispatch_query(query)

func enqueue_operation(operation: GameOperation) -> GameCommandResult:
    if _execution_queue == null:
        return GameCommandResult.configuration_error(&"missing_execution_queue", "Object context has no execution queue.")
    return _execution_queue.enqueue(operation)

func process_operations(max_operations: int = -1) -> int:
    var kernel: GameObjectKernel = get_kernel()
    if kernel == null:
        return 0
    return kernel.process_execution_queue(max_operations)

func cancel_root_operations(root_operation_id: int, reason: StringName = &"cancelled") -> void:
    if _execution_queue != null:
        _execution_queue.cancel_root(root_operation_id, reason)

func create_root_execution_context(cause_type: StringName, debug_label: String = "") -> GameExecutionContext:
    var kernel: GameObjectKernel = get_kernel()
    if kernel == null:
        return null
    return kernel.create_root_execution_context(cause_type, debug_label)

func create_child_execution_context(parent: GameExecutionContext, cause_type: StringName, debug_label: String = "") -> GameExecutionContext:
    var kernel: GameObjectKernel = get_kernel()
    if kernel == null or parent == null:
        return null
    return kernel.create_child_execution_context(parent, cause_type, debug_label)

func get_diagnostics() -> GameDiagnosticsSink:
    return _diagnostics

func get_world_port(port_id: StringName) -> Variant:
    return _world_ports.get(port_id)

func has_runtime_flag(flag_id: StringName) -> bool:
    return bool(_runtime_flags.get(flag_id, false))
