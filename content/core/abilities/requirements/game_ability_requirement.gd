@tool
extends Resource
class_name GameAbilityRequirement

# ======== EXPORT =========
@export var reason_code: StringName = &"requirement_failed"
@export_multiline var debug_message: String = "Ability requirement failed."
@export var permanent_failure: bool = false

# ====== PUBLIC ========
func evaluate(_abilities: GameAbilities, _grant: GameAbilityGrant, _request: GameAbilityActivationRequest) -> GameAbilityActivationQueryResult:
	return GameAbilityActivationQueryResult.available(_grant.get_handle_id())

func is_valid() -> bool:
	return not reason_code.is_empty()
