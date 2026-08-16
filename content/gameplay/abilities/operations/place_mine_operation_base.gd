@tool
extends GameAbilityOperation
class_name GamePlaceMineOperationBase

# ======== EXPORT =========
@export_file("*.tscn") var mine_scene_path: String = "res://content/gameplay/props/mines/prop_mine.tscn"
@export_range(0.0, 10.0, 0.1) var placement_distance: float = 1.5

# ====== PUBLIC ========
func execute(
	_abilities: GameAbilities,
	execution: GameAbilityExecution
) -> GameCommandResult:
	if execution == null or execution.get_request() == null:
		return GameCommandResult.configuration_error(
			&"place_mine_execution_missing",
			"Place-mine execution is incomplete."
		)
	var owner_handle: GameObjectHandle = execution.get_request().get_owner_handle()
	if owner_handle == null or not owner_handle.is_resolved():
		return GameCommandResult.invalid_target("Place-mine owner is unresolved.")
	var actor: Node3D = owner_handle.get_root() as Node3D
	var owner_context: GameObjectContext = owner_handle.get_context()
	if actor == null or owner_context == null:
		return GameCommandResult.invalid_target(
			"Place-mine owner root/context is unavailable."
		)
	var spawn_service: GameSpawnService = owner_context.get_world_port(
		GameWorldPortIds.SPAWN_REQUEST
	) as GameSpawnService
	if spawn_service == null:
		return GameCommandResult.configuration_error(
			&"place_mine_spawn_port_missing",
			"Place-mine ability requires the spawn.request world port."
		)
	var forward: Vector3 = -actor.global_transform.basis.z
	forward.y = 0.0
	if forward.is_zero_approx():
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var spawn_transform: Transform3D = actor.global_transform
	spawn_transform.origin = actor.global_position + forward * placement_distance
	return spawn_service.spawn(
		mine_scene_path,
		spawn_transform,
		execution.get_execution_context()
	)

func is_valid() -> bool:
	return not mine_scene_path.is_empty() and placement_distance >= 0.0
