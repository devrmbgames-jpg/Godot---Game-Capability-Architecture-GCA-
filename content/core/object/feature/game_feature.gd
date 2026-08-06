@tool
extends Node
## Base class for active components managed by a local [GameObjectKernel].
##
## A feature declares provided capabilities and dependencies, follows the kernel lifecycle,
## caches resolved providers, routes commands and queries through virtual hooks, and reports
## completed facts upward through local events.
class_name GameFeature

## Emitted when an activated feature publishes a validated local event.
signal local_event_published(event: GameLocalEvent)
## Emitted when the feature asks its owning kernel to remove it safely.
signal runtime_removal_requested(feature: GameFeature)

# ======= ENUMS =========
enum LifecycleState {
	UNDISCOVERED,
	DISCOVERED,
	REGISTERED,
	RESOLVED,
	INITIALIZED,
	ACTIVATED,
	DEACTIVATED,
	SHUTDOWN,
	CONFIGURATION_ERROR,
}

# ======== EXPORT =========
@export var feature_id: StringName = &""
@export var provided_capabilities: Array[GameCapabilitySpec] = []
@export var required_dependencies: Array[GameCapabilityDependency] = []
@export var optional_dependencies: Array[GameCapabilityDependency] = []
@export var initialization_priority: int = 0
@export var supports_reactivation: bool = true
@export var allow_multiple_instances: bool = false

# ======== PRIVATE VAR ======
var _lifecycle_state: int = LifecycleState.UNDISCOVERED
var _context: GameObjectContext = null
var _resolved_dependencies: Dictionary = {}
var _configuration_error: String = ""

# ======= OVERRIDE =======
## Returns editor warnings for invalid metadata, capabilities, dependencies, or placement.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if feature_id.is_empty():
		warnings.append("GameFeature requires a non-empty feature_id.")
	for spec: GameCapabilitySpec in provided_capabilities:
		if spec == null or not spec.is_valid():
			warnings.append("Feature '%s' contains an invalid provided capability." % feature_id)
	for dependency: GameCapabilityDependency in required_dependencies:
		if dependency == null or not dependency.is_valid():
			warnings.append("Feature '%s' contains an invalid required dependency." % feature_id)
	for dependency: GameCapabilityDependency in optional_dependencies:
		if dependency == null or not dependency.is_valid():
			warnings.append("Feature '%s' contains an invalid optional dependency." % feature_id)
	if is_inside_tree() and not (get_parent() is GameObjectKernel):
		warnings.append("GameFeature '%s' must be a direct child of GameObjectKernel." % feature_id)
	return warnings

# ====== HELPERS ========
func _set_lifecycle_state(state: int) -> void:
	_lifecycle_state = state

func _set_configuration_error(message: String) -> void:
	_configuration_error = message
	_lifecycle_state = LifecycleState.CONFIGURATION_ERROR

# ====== PUBLIC ========
## Moves an undiscovered or shut-down feature into the discovered lifecycle state.
func discover_feature() -> void:
	if _lifecycle_state == LifecycleState.UNDISCOVERED or _lifecycle_state == LifecycleState.SHUTDOWN:
		_set_lifecycle_state(LifecycleState.DISCOVERED)

## Marks a discovered feature as registered after its capabilities enter the registry.
func mark_registered() -> void:
	if _lifecycle_state == LifecycleState.DISCOVERED:
		_set_lifecycle_state(LifecycleState.REGISTERED)

## Resolves and caches declared dependencies from [param registry].
func resolve_dependencies(registry: GameCapabilityRegistry) -> GameCommandResult:
	if _lifecycle_state != LifecycleState.REGISTERED:
		return GameCommandResult.configuration_error(&"invalid_lifecycle_transition", "Feature is not in Registered state.")

	_resolved_dependencies.clear()
	for dependency: GameCapabilityDependency in required_dependencies:
		var result: GameQueryResult = registry.resolve_dependency(dependency)
		if not result.is_found():
			if dependency.lazy_resolution:
				continue
			_set_configuration_error(result.get_debug_message())
			return GameCommandResult.configuration_error(result.get_reason_code(), result.get_debug_message())
		_resolved_dependencies[dependency.capability_id] = result.get_value()
	for dependency: GameCapabilityDependency in optional_dependencies:
		var result: GameQueryResult = registry.resolve_dependency(dependency)
		if result.is_found():
			_resolved_dependencies[dependency.capability_id] = result.get_value()
	_set_lifecycle_state(LifecycleState.RESOLVED)
	return GameCommandResult.success_changed(&"dependencies_resolved")

## Injects [param context], runs [method on_game_initialize], and enters the initialized state.
func initialize_feature(context: GameObjectContext) -> GameCommandResult:
	if _lifecycle_state != LifecycleState.RESOLVED and _lifecycle_state != LifecycleState.DEACTIVATED:
		return GameCommandResult.configuration_error(&"invalid_lifecycle_transition", "Feature cannot initialize from its current state.")
	_context = context
	var result: GameCommandResult = on_game_initialize()
	if not result.is_success():
		_set_configuration_error(result.get_debug_message())
		return result
	_set_lifecycle_state(LifecycleState.INITIALIZED)
	return result

## Runs [method on_game_activate] and enters the activated state when successful.
func activate_feature() -> GameCommandResult:
	if _lifecycle_state == LifecycleState.ACTIVATED:
		return GameCommandResult.success_unchanged(&"already_activated")
	if _lifecycle_state != LifecycleState.INITIALIZED and _lifecycle_state != LifecycleState.DEACTIVATED:
		return GameCommandResult.configuration_error(&"invalid_lifecycle_transition", "Feature cannot activate from its current state.")
	if _lifecycle_state == LifecycleState.DEACTIVATED and not supports_reactivation:
		return GameCommandResult.configuration_error(&"reactivation_not_supported", "Feature does not support reactivation.")
	var result: GameCommandResult = on_game_activate()
	if result.is_success():
		_set_lifecycle_state(LifecycleState.ACTIVATED)
	return result

## Deactivates an active feature with [param reason]. Repeated calls are safe.
func deactivate_feature(reason: StringName = &"deactivated") -> void:
	if _lifecycle_state != LifecycleState.ACTIVATED:
		return
	on_game_deactivate(reason)
	_set_lifecycle_state(LifecycleState.DEACTIVATED)

## Performs terminal cleanup, clears cached dependencies, and enters the shut-down state.
func shutdown_feature() -> void:
	if _lifecycle_state == LifecycleState.SHUTDOWN:
		return
	if _lifecycle_state == LifecycleState.ACTIVATED:
		deactivate_feature(&"shutdown")
	on_game_shutdown()
	_resolved_dependencies.clear()
	_context = null
	_set_lifecycle_state(LifecycleState.SHUTDOWN)

## Re-resolves one declared dependency after a provider registry change.
func refresh_dependency(capability_id: StringName, registry: GameCapabilityRegistry) -> void:
	for dependency: GameCapabilityDependency in required_dependencies:
		if dependency.capability_id != capability_id:
			continue
		var required_result: GameQueryResult = registry.resolve_dependency(dependency)
		if required_result.is_found():
			_resolved_dependencies[capability_id] = required_result.get_value()
		else:
			notify_capability_lost(capability_id)
		return

	for dependency: GameCapabilityDependency in optional_dependencies:
		if dependency.capability_id != capability_id:
			continue
		var optional_result: GameQueryResult = registry.resolve_dependency(dependency)
		if optional_result.is_found():
			_resolved_dependencies[capability_id] = optional_result.get_value()
		else:
			_resolved_dependencies.erase(capability_id)
			on_capability_lost(capability_id)
		return

## Re-resolves all optional dependencies against [param registry].
func refresh_optional_dependencies(registry: GameCapabilityRegistry) -> void:
	for dependency: GameCapabilityDependency in optional_dependencies:
		refresh_dependency(dependency.capability_id, registry)

## Applies the configured loss policy for [param capability_id] and invokes [method on_capability_lost].
func notify_capability_lost(capability_id: StringName) -> void:
	if not _resolved_dependencies.has(capability_id):
		return

	var matched_dependency: GameCapabilityDependency = null
	for dependency: GameCapabilityDependency in required_dependencies:
		if dependency.capability_id == capability_id:
			matched_dependency = dependency
			break

	if matched_dependency != null and matched_dependency.loss_policy == GameCapabilityLossPolicy.Type.KEEP_LAST_REFERENCE:
		on_capability_lost(capability_id)
		return

	_resolved_dependencies.erase(capability_id)
	on_capability_lost(capability_id)
	if matched_dependency == null:
		return

	match matched_dependency.loss_policy:
		GameCapabilityLossPolicy.Type.DEACTIVATE_FEATURE:
			deactivate_feature(&"required_capability_lost")
		GameCapabilityLossPolicy.Type.CONFIGURATION_ERROR:
			deactivate_feature(&"required_capability_lost")
			_set_configuration_error("Required capability '%s' was removed at runtime." % capability_id)
		GameCapabilityLossPolicy.Type.IGNORE_OPTIONAL:
			pass

## Returns a cached dependency or lazily resolves it through the current context.
func get_dependency(capability_id: StringName) -> Variant:
	if _resolved_dependencies.has(capability_id):
		return _resolved_dependencies[capability_id]
	if _context == null:
		return null
	for dependency: GameCapabilityDependency in required_dependencies + optional_dependencies:
		if dependency.capability_id != capability_id or not dependency.lazy_resolution:
			continue
		var resolved_value: Variant = null
		if dependency.expected_cardinality == GameCapabilityCardinality.Type.MULTI:
			var providers: Array[GameFeature] = _context.get_capabilities(capability_id)
			if not providers.is_empty():
				resolved_value = providers
		else:
			resolved_value = _context.get_capability(capability_id)
		if resolved_value != null:
			_resolved_dependencies[capability_id] = resolved_value
		return resolved_value
	return null

## Returns whether [param capability_id] currently has a cached provider value.
func has_cached_dependency(capability_id: StringName) -> bool:
	return _resolved_dependencies.has(capability_id)

## Returns cached dependency IDs in deterministic order.
func get_resolved_dependency_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for capability_id: StringName in _resolved_dependencies.keys():
		result.append(capability_id)
	result.sort()
	return result

## Returns required dependency IDs that are not currently cached.
func get_unresolved_required_dependency_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for dependency: GameCapabilityDependency in required_dependencies:
		if not _resolved_dependencies.has(dependency.capability_id):
			result.append(dependency.capability_id)
	result.sort()
	return result

## Returns the injected object context, or [code]null[/code] before initialization or after shutdown.
func get_context() -> GameObjectContext:
	return _context

## Returns the current [enum LifecycleState].
func get_lifecycle_state() -> int:
	return _lifecycle_state

## Returns the last fatal configuration message recorded by the feature.
func get_configuration_error() -> String:
	return _configuration_error

## Publishes [param event] upward when the feature is activated and the event is complete.
func publish_local_event(event: GameLocalEvent) -> bool:
	if _lifecycle_state != LifecycleState.ACTIVATED or event == null:
		return false
	if event.get_event_type_id().is_empty() or event.get_source_handle() == null or event.get_execution_context() == null:
		if _context != null and _context.get_diagnostics() != null:
			_context.get_diagnostics().record(
				GameDiagnosticsSink.Level.ERROR,
				&"invalid_local_event",
				"Feature '%s' attempted to publish an incomplete local event." % feature_id
			)
		return false
	local_event_published.emit(event)
	return true

## Requests deferred removal by the owning kernel.
func request_runtime_removal() -> void:
	runtime_removal_requested.emit(self)

## Virtual predicate returning whether this feature can handle [param _command_type_id].
func can_handle_command(_command_type_id: StringName) -> bool:
	return false

## Virtual command handler. The default implementation returns a not-handled result.
func handle_command(command: GameCommand) -> GameCommandResult:
	return GameCommandResult.not_handled(command.get_command_type_id())

## Virtual predicate returning whether this feature can handle [param _query_type_id].
func can_handle_query(_query_type_id: StringName) -> bool:
	return false

## Virtual query handler. The default implementation returns a not-handled result.
func handle_query(query: GameQuery) -> GameQueryResult:
	return GameQueryResult.not_handled(query.get_query_type_id())

## Virtual hook called for each locally delivered gameplay event.
func on_local_event(_event: GameLocalEvent) -> void:
	pass

## Virtual initialization hook called after dependencies and context are available.
func on_game_initialize() -> GameCommandResult:
	return GameCommandResult.success_unchanged(&"feature_initialized")

## Virtual activation hook called before gameplay command handling begins.
func on_game_activate() -> GameCommandResult:
	return GameCommandResult.success_unchanged(&"feature_activated")

## Virtual deactivation hook called with the transition [param _reason].
func on_game_deactivate(_reason: StringName) -> void:
	pass

## Virtual terminal cleanup hook called before cached references are cleared.
func on_game_shutdown() -> void:
	pass

## Virtual notification hook called after [param _capability_id] is lost.
func on_capability_lost(_capability_id: StringName) -> void:
	pass
