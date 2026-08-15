@tool
extends Resource
## Virtual side-effect-free requirement for ability activation.
##
## Implementations inspect owner, grant, request, or injected query ports and
## return a structured activation query result without committing gameplay state.
class_name GameAbilityRequirement

# ======== EXPORT =========
@export var reason_code: StringName = &"requirement_failed"
@export_multiline var debug_message: String = "Ability requirement failed."
@export var permanent_failure: bool = false

# ====== PUBLIC ========
## Evaluates this requirement without applying costs, cooldowns, effects, or tags.
func evaluate(_abilities: GameAbilities, _grant: GameAbilityGrant, _request: GameAbilityActivationRequest) -> GameAbilityActivationQueryResult:
	return GameAbilityActivationQueryResult.available(_grant.get_handle_id())

## Returns whether a stable failure reason code is configured.
func is_valid() -> bool:
	return not reason_code.is_empty()
