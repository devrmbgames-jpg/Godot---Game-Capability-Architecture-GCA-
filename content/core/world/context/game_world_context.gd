@tool
extends Node
## Scene-local composition root for world service ports.
##
## Injects only approved world services into an uninitialized object kernel and
## registers the resulting stable object handle with the resolver.
class_name GameWorldContext

@export var object_resolver: GameObjectResolver = null
@export var spawn_service: GameSpawnService = null
@export var targeting_service: GameTargetingService = null
@export var time_service: GameTimeService = null
@export var persistence_coordinator: GamePersistenceCoordinator = null
@export var region_streaming_service: GameRegionStreamingService = null

## Returns editor warnings for required world services that are not assigned.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if object_resolver == null: warnings.append("GameWorldContext requires GameObjectResolver.")
	if spawn_service == null: warnings.append("GameWorldContext requires GameSpawnService.")
	if targeting_service == null: warnings.append("GameWorldContext requires GameTargetingService.")
	if time_service == null: warnings.append("GameWorldContext requires GameTimeService.")
	if persistence_coordinator == null: warnings.append("GameWorldContext requires GamePersistenceCoordinator.")
	return warnings

## Returns the approved world ports keyed by stable [GameWorldPortIds].
func get_world_ports() -> Dictionary:
	return {
		GameWorldPortIds.OBJECT_RESOLVE: object_resolver,
		GameWorldPortIds.OBJECT_REGISTER: object_resolver,
		GameWorldPortIds.SPAWN_REQUEST: spawn_service,
		GameWorldPortIds.DESPAWN_REQUEST: spawn_service,
		GameWorldPortIds.TARGETING_QUERY: targeting_service,
		GameWorldPortIds.TIME_SIMULATION: time_service,
		GameWorldPortIds.PERSISTENCE_REGISTER: persistence_coordinator,
		GameWorldPortIds.STREAMING_REGION: region_streaming_service,
	}

## Injects world ports, initializes [param kernel], and registers its object handle.
func bind_kernel(kernel: GameObjectKernel) -> GameCommandResult:
	if kernel == null: return GameCommandResult.invalid_target("World context cannot bind a null kernel.")
	if object_resolver == null: return GameCommandResult.configuration_error(&"missing_object_resolver", "World context requires resolver.")
	if kernel.get_lifecycle_state() != GameObjectKernel.LifecycleState.UNINITIALIZED:
		return GameCommandResult.configuration_error(&"kernel_already_initialized", "Inject world ports before initialization.")
	kernel.injected_world_ports = get_world_ports()
	var result: GameCommandResult = kernel.initialize_kernel()
	if not result.is_success(): return result
	return object_resolver.register_handle(kernel.get_object_context().get_object_handle())
