@tool
extends GameAbilityOperation
class_name GameDodgeOperationBase

@export_range(0.0, 10.0, 0.1) var distance: float = 4.0

func execute(
	_abilities: GameAbilities,
	execution: GameAbilityExecution
) -> GameCommandResult:
	if execution == null or execution.get_request() == null:
		return GameCommandResult.configuration_error(
			&"simple_dodge_execution_missing",
			"Dodge execution is missing."
		)
	var owner_handle: GameObjectHandle = execution.get_request().get_owner_handle()
	if owner_handle == null or not owner_handle.is_resolved():
		return GameCommandResult.invalid_target("Dodge owner is unresolved.")
	var body: CharacterBody3D = owner_handle.get_root() as CharacterBody3D
	if body == null:
		return GameCommandResult.invalid_target(
			"Simple dodge requires CharacterBody3D owner root."
		)
	var direction: Vector3 = -body.global_transform.basis.z
	direction.y = 0.0
	if direction.is_zero_approx():
		return GameCommandResult.rejected_temporary(
			&"simple_dodge_no_direction",
			"Dodge direction is empty."
		)
	body.move_and_collide(direction.normalized() * distance)
	return GameCommandResult.success_changed(&"simple_dodge_completed")

func is_valid() -> bool:
	return distance >= 0.0
