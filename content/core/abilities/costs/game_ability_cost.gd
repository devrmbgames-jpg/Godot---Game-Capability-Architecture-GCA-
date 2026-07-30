@tool
extends Resource
class_name GameAbilityCost

# ======= ENUMS =========
enum Timing { ON_COMMIT, EXECUTION_PHASE, PER_TICK, ON_SUCCESSFUL_HIT, ON_COMPLETION }

# ======== EXPORT =========
@export var timing: Timing = Timing.ON_COMMIT
@export var refund_on_cancel: bool = false

# ====== PUBLIC ========
func can_pay(_abilities: GameAbilities, _grant: GameAbilityGrant, _request: GameAbilityActivationRequest) -> GameCommandResult:
	return GameCommandResult.success_unchanged(&"cost_payable")

func prepare(_abilities: GameAbilities, _grant: GameAbilityGrant, _request: GameAbilityActivationRequest) -> Variant:
	return null

func commit(_abilities: GameAbilities, _grant: GameAbilityGrant, _request: GameAbilityActivationRequest, _prepared: Variant) -> GameCommandResult:
	return GameCommandResult.success_unchanged(&"cost_committed")

func rollback(_abilities: GameAbilities, _grant: GameAbilityGrant, _request: GameAbilityActivationRequest, _prepared: Variant) -> void:
	pass

func refund(_abilities: GameAbilities, _grant: GameAbilityGrant, _execution: GameAbilityExecution, _prepared: Variant) -> void:
	pass

func is_valid() -> bool:
	return true
