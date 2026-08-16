@tool
extends GameAbilityOperation
class_name GameAttackOperationBase

# ======== EXPORT =========
@export_range(0.1, 20.0, 0.1) var attack_radius: float = 2.0
@export_range(0.0, 10000.0, 0.1) var attack_damage: float = 25.0
@export var required_tags: Array[StringName] = []
@export var damage_tags: Array[StringName] = [&"damage.melee"]

# ====== PUBLIC ========
func execute(
	_abilities: GameAbilities,
	execution: GameAbilityExecution
) -> GameCommandResult:
	if execution == null or execution.get_request() == null:
		return GameCommandResult.configuration_error(
			&"simple_attack_execution_missing",
			"Attack execution is missing."
		)

	var request: GameAbilityActivationRequest = execution.get_request()
	var source_handle: GameObjectHandle = request.get_owner_handle()
	if source_handle == null or not source_handle.is_resolved():
		return GameCommandResult.invalid_target("Attack owner is unresolved.")

	var actor: Node3D = source_handle.get_root() as Node3D
	var source_context: GameObjectContext = source_handle.get_context()
	if actor == null or source_context == null:
		return GameCommandResult.invalid_target("Attack owner root/context is unavailable.")

	var targeting_service: GameTargetingService = (
		source_context.get_world_port(GameWorldPortIds.TARGETING_QUERY)
		as GameTargetingService
	)
	if targeting_service == null:
		return GameCommandResult.configuration_error(
			&"simple_attack_targeting_missing",
			"Owner has no targeting world port."
		)

	var excluded_ids: Array[StringName] = [source_handle.get_stable_id()]
	var query: Dictionary = targeting_service.query_sphere(
		actor.global_position,
		attack_radius,
		GameCapabilityIds.DAMAGE_RECEIVER,
		required_tags,
		excluded_ids
	)
	var affected_count: int = 0

	for value: Variant in query.get(&"handles", []):
		var target_handle: GameObjectHandle = value as GameObjectHandle
		if target_handle == null or not target_handle.is_resolved():
			continue
		var target_context: GameObjectContext = target_handle.get_context()
		if target_context == null:
			continue
		var receiver: GameDamageReceiver = target_context.get_capability(
			GameCapabilityIds.DAMAGE_RECEIVER
		) as GameDamageReceiver
		if receiver == null:
			continue

		var damage_request := GameDamageRequest.new(
			source_handle,
			source_handle,
			target_handle,
			attack_damage,
			damage_tags,
			execution.get_execution_context()
		)
		if receiver.apply_damage(damage_request).is_success():
			affected_count += 1

	if affected_count == 0:
		return GameCommandResult.success_unchanged(&"simple_attack_no_targets")
	return GameCommandResult.success_changed(
		&"simple_attack_applied",
		affected_count
	)

func is_valid() -> bool:
	return attack_radius > 0.0 and attack_damage >= 0.0
