@tool
extends Node
class_name GameObjectKernel

signal kernel_initialized(kernel: GameObjectKernel)
signal kernel_activated(kernel: GameObjectKernel)
signal kernel_deactivated(kernel: GameObjectKernel, reason: StringName)
signal kernel_shutdown(kernel: GameObjectKernel)
signal local_event_dispatched(event: GameLocalEvent)

# ======= ENUMS =========
enum LifecycleState {
	UNINITIALIZED,
	DISCOVERING,
	VALIDATING,
	INITIALIZING,
	ACTIVATED,
	DEACTIVATED,
	SHUTDOWN,
	CONFIGURATION_ERROR,
}

# ======== EXPORT =========
@export var object_root_override: Node = null
@export var auto_initialize: bool = true
@export var strict_validation: bool = true
@export var require_identity: bool = true
@export_range(1, 128, 1) var max_operation_depth: int = 16
@export_range(1, 4096, 1) var max_operations_per_root: int = 128
@export_range(1, 64, 1) var max_repeats_per_guard: int = 4
@export_enum("Continue", "Stop Root", "Stop All") var operation_error_policy: int = GameExecutionQueue.ErrorPolicy.CONTINUE
@export var injected_world_ports: Dictionary = {}

# ======== PRIVATE VAR ======
var _lifecycle_state: int = LifecycleState.UNINITIALIZED
var _object_root: Node = null
var _features: Array[GameFeature] = []
var _feature_by_id: Dictionary = {}
var _initialization_order: Array[GameFeature] = []
var _registry := GameCapabilityRegistry.new()
var _execution_queue := GameExecutionQueue.new()
var _diagnostics := GameDiagnosticsSink.new()
var _identity: GameObjectIdentity = null
var _tag_container: GameTagContainer = null
var _object_context: GameObjectContext = null
var _event_sequence: int = 0
var _operation_id_counter: int = 0
var _is_dispatching_event: bool = false
var _is_mutating_features: bool = false
var _pending_feature_mutations: Array[Callable] = []
var _pending_local_events: Array[GameLocalEvent] = []
var _configuration_errors: PackedStringArray = PackedStringArray()

# ======= OVERRIDE =======
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if auto_initialize:
		initialize_kernel()

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	shutdown_kernel()

func _get_configuration_warnings() -> PackedStringArray:
	return _collect_static_warnings()

# ====== HELPERS ========
func _resolve_object_root() -> Node:
	if object_root_override != null:
		return object_root_override
	return get_parent()

func _discover_direct_features() -> Array[GameFeature]:
	var result: Array[GameFeature] = []
	for child: Node in get_children():
		if child is GameFeature:
			result.append(child as GameFeature)
	return result

func _validate_feature_composition(features: Array[GameFeature]) -> GameCommandResult:
	var feature_ids: Dictionary = {}
	var features_by_script: Dictionary = {}
	for feature: GameFeature in features:
		if feature.feature_id.is_empty():
			return GameCommandResult.configuration_error(&"empty_feature_id", "A feature has an empty feature_id.")
		if feature_ids.has(feature.feature_id):
			return GameCommandResult.configuration_error(
				&"duplicate_feature_id",
				"Duplicate feature_id '%s'." % feature.feature_id
			)
		feature_ids[feature.feature_id] = feature

		var feature_script: Script = feature.get_script() as Script
		if feature_script == null:
			continue
		if features_by_script.has(feature_script):
			var previous: GameFeature = features_by_script[feature_script] as GameFeature
			if not previous.allow_multiple_instances or not feature.allow_multiple_instances:
				return GameCommandResult.configuration_error(
					&"duplicate_feature_type",
					"Feature type '%s' does not allow multiple instances." % feature_script.resource_path
				)
		else:
			features_by_script[feature_script] = feature
	return GameCommandResult.success_unchanged(&"feature_composition_valid")

func _feature_sort_before(a: GameFeature, b: GameFeature) -> bool:
	if a.initialization_priority != b.initialization_priority:
		return a.initialization_priority < b.initialization_priority
	if a.feature_id != b.feature_id:
		return String(a.feature_id) < String(b.feature_id)
	return a.get_index() < b.get_index()

func _collect_static_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var object_root: Node = _resolve_object_root()
	if object_root == null:
		warnings.append("GameObjectKernel requires an object root parent or object_root_override.")

	var features: Array[GameFeature] = _discover_direct_features()
	var feature_ids: Dictionary = {}
	var provider_specs: Dictionary = {}
	var identity_count: int = 0
	for feature: GameFeature in features:
		if feature.feature_id.is_empty():
			warnings.append("A child GameFeature has an empty feature_id.")
		elif feature_ids.has(feature.feature_id):
			warnings.append("Duplicate feature_id '%s'." % feature.feature_id)
		else:
			feature_ids[feature.feature_id] = feature
		if feature is GameObjectIdentity:
			identity_count += 1
		for spec: GameCapabilitySpec in feature.provided_capabilities:
			if spec == null or not spec.is_valid():
				warnings.append("Feature '%s' has an invalid capability specification." % feature.feature_id)
				continue
			var specs: Array = provider_specs.get(spec.capability_id, [])
			specs.append(spec)
			provider_specs[spec.capability_id] = specs

	if require_identity and identity_count == 0:
		warnings.append("Kernel requires exactly one GameObjectIdentity child.")
	elif identity_count > 1:
		warnings.append("Kernel contains more than one GameObjectIdentity child.")

	for capability_id: StringName in provider_specs.keys():
		var specs: Array = provider_specs[capability_id]
		if specs.size() <= 1:
			continue
		for spec: GameCapabilitySpec in specs:
			if spec.cardinality != GameCapabilityCardinality.Type.MULTI:
				warnings.append("Capability '%s' has multiple providers but is not multi." % capability_id)
				break

	for feature: GameFeature in features:
		for dependency: GameCapabilityDependency in feature.required_dependencies:
			if dependency == null or not dependency.is_valid():
				continue
			if not provider_specs.has(dependency.capability_id) and not dependency.lazy_resolution:
				warnings.append("Feature '%s' is missing required capability '%s'." % [feature.feature_id, dependency.capability_id])

	if _has_dependency_cycle(features, provider_specs):
		warnings.append("Feature dependency cycle detected.")
	return warnings

func _has_dependency_cycle(features: Array[GameFeature], provider_specs: Dictionary) -> bool:
	var edges: Dictionary = {}
	for feature: GameFeature in features:
		edges[feature] = []
	for dependent: GameFeature in features:
		for dependency: GameCapabilityDependency in dependent.required_dependencies:
			if dependency == null or not provider_specs.has(dependency.capability_id):
				continue
			for provider: GameFeature in features:
				for spec: GameCapabilitySpec in provider.provided_capabilities:
					if spec != null and spec.capability_id == dependency.capability_id and provider != dependent:
						(edges[provider] as Array).append(dependent)
	var visiting: Dictionary = {}
	var visited: Dictionary = {}
	for feature: GameFeature in features:
		if _detect_cycle_from(feature, edges, visiting, visited):
			return true
	return false

func _detect_cycle_from(feature: GameFeature, edges: Dictionary, visiting: Dictionary, visited: Dictionary) -> bool:
	if visiting.get(feature, false):
		return true
	if visited.get(feature, false):
		return false
	visiting[feature] = true
	for next_feature: GameFeature in edges.get(feature, []):
		if _detect_cycle_from(next_feature, edges, visiting, visited):
			return true
	visiting.erase(feature)
	visited[feature] = true
	return false

func _build_initialization_order() -> GameCommandResult:
	var indegree: Dictionary = {}
	var outgoing: Dictionary = {}
	for feature: GameFeature in _features:
		indegree[feature] = 0
		outgoing[feature] = []

	for dependent: GameFeature in _features:
		for dependency: GameCapabilityDependency in dependent.required_dependencies:
			var providers: Array[GameFeature] = _registry.get_all(dependency.capability_id)
			for provider: GameFeature in providers:
				if provider == dependent:
					continue
				if dependent not in (outgoing[provider] as Array):
					(outgoing[provider] as Array).append(dependent)
					indegree[dependent] = int(indegree[dependent]) + 1

	var ready_features: Array[GameFeature] = []
	for feature: GameFeature in _features:
		if int(indegree[feature]) == 0:
			ready_features.append(feature)
	ready_features.sort_custom(_feature_sort_before)

	_initialization_order.clear()
	while not ready_features.is_empty():
		var current: GameFeature = ready_features.pop_front()
		_initialization_order.append(current)
		var next_features: Array = outgoing[current]
		next_features.sort_custom(_feature_sort_before)
		for dependent: GameFeature in next_features:
			indegree[dependent] = int(indegree[dependent]) - 1
			if int(indegree[dependent]) == 0:
				ready_features.append(dependent)
				ready_features.sort_custom(_feature_sort_before)

	if _initialization_order.size() != _features.size():
		return GameCommandResult.configuration_error(&"dependency_cycle", "Feature dependency cycle detected.")
	return GameCommandResult.success_changed(&"initialization_order_built")

func _register_all_capabilities() -> GameCommandResult:
	for feature: GameFeature in _features:
		for spec: GameCapabilitySpec in feature.provided_capabilities:
			var result: GameCommandResult = _registry.register_provider(spec, feature)
			if not result.is_success():
				return result
		feature.mark_registered()
	return GameCommandResult.success_changed(&"capabilities_registered")

func _resolve_special_features() -> GameCommandResult:
	_identity = null
	_tag_container = null
	for feature: GameFeature in _features:
		if feature is GameObjectIdentity:
			if _identity != null:
				return GameCommandResult.configuration_error(&"duplicate_identity", "Kernel has more than one GameObjectIdentity.")
			_identity = feature as GameObjectIdentity
		elif feature is GameTagContainer:
			if _tag_container != null:
				return GameCommandResult.configuration_error(&"duplicate_tag_container", "Kernel has more than one GameTagContainer.")
			_tag_container = feature as GameTagContainer

	if require_identity and _identity == null:
		return GameCommandResult.configuration_error(&"missing_identity", "Kernel requires GameObjectIdentity.")
	if _identity != null:
		return _identity.prepare_identity(_object_root, self)
	return GameCommandResult.success_unchanged(&"identity_optional")

func _connect_feature_signals(feature: GameFeature) -> void:
	if not feature.local_event_published.is_connected(_on_feature_local_event_published):
		feature.local_event_published.connect(_on_feature_local_event_published)
	if not feature.runtime_removal_requested.is_connected(_on_runtime_removal_requested):
		feature.runtime_removal_requested.connect(_on_runtime_removal_requested)

func _disconnect_feature_signals(feature: GameFeature) -> void:
	if feature.local_event_published.is_connected(_on_feature_local_event_published):
		feature.local_event_published.disconnect(_on_feature_local_event_published)
	if feature.runtime_removal_requested.is_connected(_on_runtime_removal_requested):
		feature.runtime_removal_requested.disconnect(_on_runtime_removal_requested)

func _rollback_initialization() -> void:
	var rollback_order: Array[GameFeature] = _initialization_order.duplicate()
	if rollback_order.is_empty():
		rollback_order = _features.duplicate()
	for index: int in range(rollback_order.size() - 1, -1, -1):
		var feature: GameFeature = rollback_order[index]
		feature.shutdown_feature()
		_disconnect_feature_signals(feature)
	_registry.clear()
	if _identity != null:
		_identity.invalidate_handle()
	_object_context = null
	_pending_local_events.clear()
	_pending_feature_mutations.clear()


func _record_configuration_error(result: GameCommandResult) -> GameCommandResult:
	_lifecycle_state = LifecycleState.CONFIGURATION_ERROR
	_configuration_errors.append(result.get_debug_message())
	_diagnostics.record(
		GameDiagnosticsSink.Level.FATAL_CONFIGURATION_ERROR,
		result.get_reason_code(),
		result.get_debug_message()
	)
	return result

func _flush_pending_feature_mutations() -> void:
	if _lifecycle_state != LifecycleState.ACTIVATED:
		_pending_feature_mutations.clear()
		return
	if _is_dispatching_event or _is_mutating_features:
		return
	while not _pending_feature_mutations.is_empty():
		var mutation: Callable = _pending_feature_mutations.pop_front()
		if mutation.is_valid():
			mutation.call()

func _perform_register_runtime_feature(feature: GameFeature) -> GameCommandResult:
	_is_mutating_features = true
	if feature == null or feature.get_parent() != self:
		_is_mutating_features = false
		return GameCommandResult.configuration_error(&"invalid_feature_parent", "Runtime feature must be a direct child of the kernel.")
	if feature is GameObjectIdentity or feature is GameTagContainer:
		_is_mutating_features = false
		return GameCommandResult.configuration_error(
			&"immutable_infrastructure_feature",
            "Identity and tag-container composition cannot change after kernel activation."
		)
	if feature.feature_id.is_empty():
		_is_mutating_features = false
		return GameCommandResult.configuration_error(&"empty_feature_id", "Runtime feature requires a non-empty feature_id.")
	if _feature_by_id.has(feature.feature_id):
		_is_mutating_features = false
		return GameCommandResult.configuration_error(&"duplicate_feature_id", "Runtime feature_id already exists.")
	for existing: GameFeature in _features:
		if existing.get_script() == feature.get_script() and (not existing.allow_multiple_instances or not feature.allow_multiple_instances):
			_is_mutating_features = false
			return GameCommandResult.configuration_error(&"duplicate_feature_type", "Feature type does not allow multiple instances.")

	feature.discover_feature()
	_connect_feature_signals(feature)
	for spec: GameCapabilitySpec in feature.provided_capabilities:
		var register_result: GameCommandResult = _registry.register_provider(spec, feature)
		if not register_result.is_success():
			for rollback_spec: GameCapabilitySpec in feature.provided_capabilities:
				_registry.unregister_provider(rollback_spec.capability_id, feature)
			feature.shutdown_feature()
			_disconnect_feature_signals(feature)
			_is_mutating_features = false
			return register_result
	feature.mark_registered()
	var resolve_result: GameCommandResult = feature.resolve_dependencies(_registry)
	if not resolve_result.is_success():
		for spec: GameCapabilitySpec in feature.provided_capabilities:
			_registry.unregister_provider(spec.capability_id, feature)
		feature.shutdown_feature()
		_disconnect_feature_signals(feature)
		_is_mutating_features = false
		return resolve_result
	var initialize_result: GameCommandResult = feature.initialize_feature(_object_context)
	if not initialize_result.is_success():
		for spec: GameCapabilitySpec in feature.provided_capabilities:
			_registry.unregister_provider(spec.capability_id, feature)
		feature.shutdown_feature()
		_disconnect_feature_signals(feature)
		_is_mutating_features = false
		return initialize_result
	var activate_result: GameCommandResult = feature.activate_feature()
	if not activate_result.is_success():
		for spec: GameCapabilitySpec in feature.provided_capabilities:
			_registry.unregister_provider(spec.capability_id, feature)
		feature.shutdown_feature()
		_disconnect_feature_signals(feature)
		_is_mutating_features = false
		return activate_result

	_features.append(feature)
	_features.sort_custom(_feature_sort_before)
	_feature_by_id[feature.feature_id] = feature
	_initialization_order.append(feature)
	for existing: GameFeature in _features:
		for provided_spec: GameCapabilitySpec in feature.provided_capabilities:
			existing.refresh_dependency(provided_spec.capability_id, _registry)
	_is_mutating_features = false
	return GameCommandResult.success_changed(&"runtime_feature_registered", feature)

func _perform_remove_runtime_feature(feature: GameFeature) -> GameCommandResult:
	_is_mutating_features = true
	if feature == null or feature not in _features:
		_is_mutating_features = false
		return GameCommandResult.success_unchanged(&"feature_not_registered")
	if feature is GameObjectIdentity or feature is GameTagContainer:
		_is_mutating_features = false
		return GameCommandResult.configuration_error(
			&"immutable_infrastructure_feature",
            "Identity and tag-container composition cannot change after kernel activation."
		)

	var removed_capabilities: Array[StringName] = []
	for spec: GameCapabilitySpec in feature.provided_capabilities:
		if _registry.unregister_provider(spec.capability_id, feature):
			removed_capabilities.append(spec.capability_id)

	feature.deactivate_feature(&"runtime_removed")
	feature.shutdown_feature()
	_disconnect_feature_signals(feature)
	_features.erase(feature)
	_initialization_order.erase(feature)
	_feature_by_id.erase(feature.feature_id)

	for existing: GameFeature in _features:
		for capability_id: StringName in removed_capabilities:
			existing.refresh_dependency(capability_id, _registry)
	_is_mutating_features = false
	return GameCommandResult.success_changed(&"runtime_feature_removed", feature)

func _route_command_locally(command: GameCommand) -> GameCommandResult:
	if _lifecycle_state != LifecycleState.ACTIVATED:
		return GameCommandResult.rejected_temporary(&"target_not_active", "Target kernel is not active.")
	var candidate_features: Array[GameFeature] = []
	var required_capability_id: StringName = command.get_required_capability_id()
	if not required_capability_id.is_empty():
		candidate_features = _registry.get_all(required_capability_id)
		if candidate_features.is_empty():
			return GameCommandResult.missing_capability(required_capability_id)
	else:
		candidate_features = _initialization_order.duplicate()

	for feature: GameFeature in candidate_features:
		if feature.get_lifecycle_state() == GameFeature.LifecycleState.ACTIVATED and feature.can_handle_command(command.get_command_type_id()):
			return feature.handle_command(command)
	return GameCommandResult.not_handled(command.get_command_type_id())

func _route_query_locally(query: GameQuery) -> GameQueryResult:
	var candidate_features: Array[GameFeature] = []
	var required_capability_id: StringName = query.get_required_capability_id()
	if not required_capability_id.is_empty():
		candidate_features = _registry.get_all(required_capability_id)
		if candidate_features.is_empty():
			return GameQueryResult.missing_capability(required_capability_id)
	else:
		candidate_features = _initialization_order.duplicate()

	for feature: GameFeature in candidate_features:
		var feature_state: int = feature.get_lifecycle_state()
		if (feature_state == GameFeature.LifecycleState.ACTIVATED or feature_state == GameFeature.LifecycleState.DEACTIVATED) and feature.can_handle_query(query.get_query_type_id()):
			return feature.handle_query(query)
	return GameQueryResult.not_handled(query.get_query_type_id())

# ====== PUBLIC ========
func initialize_kernel() -> GameCommandResult:
	if _lifecycle_state == LifecycleState.ACTIVATED:
		return GameCommandResult.success_unchanged(&"kernel_already_activated")
	_lifecycle_state = LifecycleState.DISCOVERING
	_configuration_errors.clear()
	_object_root = _resolve_object_root()
	if _object_root == null:
		return _record_configuration_error(GameCommandResult.configuration_error(&"missing_object_root", "Kernel has no object root."))

	_features = _discover_direct_features()
	_feature_by_id.clear()
	_registry.clear()
	var composition_result: GameCommandResult = _validate_feature_composition(_features)
	if not composition_result.is_success():
		return _record_configuration_error(composition_result)
	for feature: GameFeature in _features:
		_feature_by_id[feature.feature_id] = feature
		feature.discover_feature()
		_connect_feature_signals(feature)

	var static_warnings: PackedStringArray = _collect_static_warnings()
	for warning: String in static_warnings:
		_diagnostics.record(GameDiagnosticsSink.Level.WARNING, &"static_configuration_warning", warning)
	if strict_validation and not static_warnings.is_empty():
		_rollback_initialization()
		return _record_configuration_error(
			GameCommandResult.configuration_error(&"static_validation_failed", static_warnings[0])
		)

	_lifecycle_state = LifecycleState.VALIDATING
	var special_result: GameCommandResult = _resolve_special_features()
	if not special_result.is_success():
		_rollback_initialization()
		return _record_configuration_error(special_result)
	var register_result: GameCommandResult = _register_all_capabilities()
	if not register_result.is_success():
		_rollback_initialization()
		return _record_configuration_error(register_result)
	var order_result: GameCommandResult = _build_initialization_order()
	if not order_result.is_success():
		_rollback_initialization()
		return _record_configuration_error(order_result)

	for feature: GameFeature in _initialization_order:
		var resolve_result: GameCommandResult = feature.resolve_dependencies(_registry)
		if not resolve_result.is_success():
			_rollback_initialization()
			return _record_configuration_error(resolve_result)

	_execution_queue.configure(max_operation_depth, max_operations_per_root, max_repeats_per_guard, operation_error_policy)
	_execution_queue.set_diagnostics(_diagnostics)
	var object_handle: GameObjectHandle = _identity.get_object_handle() if _identity != null else GameObjectHandle.new(&"", _object_root.get_instance_id())
	if _identity == null:
		object_handle.resolve(_object_root, self)
	_object_context = GameObjectContext.new(
		self,
		_object_root,
		_identity,
		object_handle,
		_registry,
		_tag_container,
		_execution_queue,
		_diagnostics,
		injected_world_ports,
		{
			&"editor": Engine.is_editor_hint(),
			&"runtime": not Engine.is_editor_hint(),
		}
	)

	_lifecycle_state = LifecycleState.INITIALIZING
	for feature: GameFeature in _initialization_order:
		var initialize_result: GameCommandResult = feature.initialize_feature(_object_context)
		if not initialize_result.is_success():
			_rollback_initialization()
			return _record_configuration_error(initialize_result)
	kernel_initialized.emit(self)

	for feature: GameFeature in _initialization_order:
		var activate_result: GameCommandResult = feature.activate_feature()
		if not activate_result.is_success():
			_rollback_initialization()
			return _record_configuration_error(activate_result)

	_lifecycle_state = LifecycleState.ACTIVATED
	kernel_activated.emit(self)
	return GameCommandResult.success_changed(&"kernel_activated", self)

func deactivate_kernel(reason: StringName = &"deactivated") -> void:
	if _lifecycle_state != LifecycleState.ACTIVATED:
		return
	for index: int in range(_initialization_order.size() - 1, -1, -1):
		_initialization_order[index].deactivate_feature(reason)
	_lifecycle_state = LifecycleState.DEACTIVATED
	kernel_deactivated.emit(self, reason)

func reactivate_kernel() -> GameCommandResult:
	if _lifecycle_state != LifecycleState.DEACTIVATED:
		return GameCommandResult.configuration_error(&"invalid_kernel_state", "Kernel is not deactivated.")
	for feature: GameFeature in _initialization_order:
		var result: GameCommandResult = feature.activate_feature()
		if not result.is_success():
			return _record_configuration_error(result)
	_lifecycle_state = LifecycleState.ACTIVATED
	kernel_activated.emit(self)
	return GameCommandResult.success_changed(&"kernel_reactivated")

func shutdown_kernel() -> void:
	if _lifecycle_state == LifecycleState.SHUTDOWN or _lifecycle_state == LifecycleState.UNINITIALIZED:
		return
	_execution_queue.clear()
	for index: int in range(_initialization_order.size() - 1, -1, -1):
		_initialization_order[index].shutdown_feature()
		_disconnect_feature_signals(_initialization_order[index])
	if _identity != null:
		_identity.invalidate_handle()
	_registry.clear()
	_pending_feature_mutations.clear()
	_pending_local_events.clear()
	_is_dispatching_event = false
	_is_mutating_features = false
	_features.clear()
	_feature_by_id.clear()
	_initialization_order.clear()
	_object_context = null
	_lifecycle_state = LifecycleState.SHUTDOWN
	kernel_shutdown.emit(self)

func dispatch_command(command: GameCommand) -> GameCommandResult:
	if command == null:
		return GameCommandResult.configuration_error(&"missing_command", "Command is null.")
	if command.get_target_handle() == null or not command.get_target_handle().is_resolved():
		return GameCommandResult.invalid_target()
	if command.get_command_type_id().is_empty():
		return GameCommandResult.configuration_error(&"empty_command_type", "Command type ID is empty.")
	if command.get_execution_context() == null:
		return GameCommandResult.configuration_error(&"missing_execution_context", "Command requires an execution context.")
	var target_kernel: GameObjectKernel = command.get_target_handle().get_kernel()
	if target_kernel == null:
		return GameCommandResult.invalid_target()
	var result: GameCommandResult = target_kernel._route_command_locally(command)
	result.attach_source_operation_id(command.get_execution_context().get_operation_id())
	target_kernel.get_diagnostics().trace_command(command, result)
	return result

func dispatch_query(query: GameQuery) -> GameQueryResult:
	if query == null:
		return GameQueryResult.failure(&"missing_query", "Query is null.")
	if query.get_target_handle() == null or not query.get_target_handle().is_resolved():
		return GameQueryResult.invalid_target()
	if query.get_query_type_id().is_empty():
		return GameQueryResult.failure(&"empty_query_type", "Query type ID is empty.")
	var target_kernel: GameObjectKernel = query.get_target_handle().get_kernel()
	if target_kernel == null:
		return GameQueryResult.invalid_target()
	return target_kernel._route_query_locally(query)

func register_runtime_feature(feature: GameFeature) -> GameCommandResult:
	if _lifecycle_state != LifecycleState.ACTIVATED:
		return GameCommandResult.configuration_error(&"kernel_not_active", "Runtime feature registration requires an active kernel.")
	if _is_dispatching_event or _is_mutating_features or _execution_queue.is_processing():
		_pending_feature_mutations.append(_perform_register_runtime_feature.bind(feature))
		return GameCommandResult.success_unchanged(&"feature_registration_queued")
	return _perform_register_runtime_feature(feature)

func remove_runtime_feature(feature: GameFeature) -> GameCommandResult:
	if _lifecycle_state != LifecycleState.ACTIVATED:
		return GameCommandResult.configuration_error(&"kernel_not_active", "Runtime feature removal requires an active kernel.")
	if _is_dispatching_event or _is_mutating_features or _execution_queue.is_processing():
		_pending_feature_mutations.append(_perform_remove_runtime_feature.bind(feature))
		return GameCommandResult.success_unchanged(&"feature_removal_queued")
	return _perform_remove_runtime_feature(feature)

func process_execution_queue(max_operations: int = -1) -> int:
	var processed: int = _execution_queue.process(max_operations)
	_flush_pending_feature_mutations()
	return processed

func create_root_execution_context(cause_type: StringName, debug_label: String = "") -> GameExecutionContext:
	_operation_id_counter += 1
	var handle: GameObjectHandle = get_object_handle()
	var new_seed: int = abs(hash("%s:%s" % [handle.get_runtime_instance_id() if handle != null else 0, _operation_id_counter]))
	return GameExecutionContext.create_root(_operation_id_counter, handle, cause_type, new_seed, 0, debug_label)

func create_child_execution_context(parent: GameExecutionContext, cause_type: StringName, debug_label: String = "") -> GameExecutionContext:
	_operation_id_counter += 1
	return parent.create_child(_operation_id_counter, get_object_handle(), cause_type, debug_label)

func get_object_context() -> GameObjectContext:
	return _object_context

func get_object_handle() -> GameObjectHandle:
	if _object_context != null:
		return _object_context.get_object_handle()
	if _identity != null:
		return _identity.get_object_handle()
	return null

func get_lifecycle_state() -> int:
	return _lifecycle_state

func get_feature(feature_id: StringName) -> GameFeature:
	return _feature_by_id.get(feature_id) as GameFeature

func get_features() -> Array[GameFeature]:
	return _features.duplicate()

func get_capability_registry() -> GameCapabilityRegistry:
	return _registry

func get_diagnostics() -> GameDiagnosticsSink:
	return _diagnostics

func get_configuration_errors() -> PackedStringArray:
	return _configuration_errors

func get_debug_snapshot() -> Dictionary:
	var feature_snapshot: Array[Dictionary] = []
	for feature: GameFeature in _initialization_order:
		feature_snapshot.append({
			"feature_id": feature.feature_id,
			"lifecycle_state": feature.get_lifecycle_state(),
			"configuration_error": feature.get_configuration_error(),
			"resolved_dependencies": feature.get_resolved_dependency_ids(),
			"unresolved_required_dependencies": feature.get_unresolved_required_dependency_ids(),
		})
	return {
		"lifecycle_state": _lifecycle_state,
		"object_handle": get_object_handle().to_dictionary() if get_object_handle() != null else {},
		"features": feature_snapshot,
		"capabilities": _registry.get_debug_snapshot(),
		"tags": _tag_container.get_debug_snapshot() if _tag_container != null else {},
		"operation_queue": _execution_queue.get_debug_snapshot(),
		"configuration_errors": _configuration_errors,
		"diagnostics": _diagnostics.get_debug_snapshot(),
	}

# ===== SLOTS =======
func _on_feature_local_event_published(event: GameLocalEvent) -> void:
	if event == null or _lifecycle_state != LifecycleState.ACTIVATED:
		return
	_pending_local_events.append(event)
	if _is_dispatching_event:
		return

	_is_dispatching_event = true
	while not _pending_local_events.is_empty():
		var current_event: GameLocalEvent = _pending_local_events.pop_front()
		_event_sequence += 1
		current_event.set_sequence(_event_sequence)
		_diagnostics.trace_event(current_event)
		var delivery_order: Array[GameFeature] = _initialization_order.duplicate()
		for feature: GameFeature in delivery_order:
			if feature.get_lifecycle_state() == GameFeature.LifecycleState.ACTIVATED:
				feature.on_local_event(current_event)
		local_event_dispatched.emit(current_event)
	_is_dispatching_event = false
	_flush_pending_feature_mutations()

func _on_runtime_removal_requested(feature: GameFeature) -> void:
	remove_runtime_feature(feature)
