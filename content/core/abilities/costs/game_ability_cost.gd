@tool
extends Resource
## Virtual contract for an atomic ability cost.
##
## Implementations separate side-effect-free validation, preparation, commit,
## rollback, and optional gameplay refund so multi-cost activations can commit
## consistently.
class_name GameAbilityCost

# ======= ENUMS =========
enum Timing { ON_COMMIT, EXECUTION_PHASE, PER_TICK, ON_SUCCESSFUL_HIT, ON_COMPLETION }

# ======== EXPORT =========
@export var timing: Timing = Timing.ON_COMMIT
@export var refund_on_cancel: bool = false

# ====== PUBLIC ========
## Checks whether the owner can pay this cost without mutating gameplay state.
func can_pay(_abilities: GameAbilities, _grant: GameAbilityGrant, _request: GameAbilityActivationRequest) -> GameCommandResult:
	return GameCommandResult.success_unchanged(&"cost_payable")

## Captures the data required to commit or roll back this cost.
func prepare(_abilities: GameAbilities, _grant: GameAbilityGrant, _request: GameAbilityActivationRequest) -> Variant:
	return null

## Applies the prepared cost mutation.
func commit(_abilities: GameAbilities, _grant: GameAbilityGrant, _request: GameAbilityActivationRequest, _prepared: Variant) -> GameCommandResult:
	return GameCommandResult.success_unchanged(&"cost_committed")

## Restores state when a multi-cost commit fails before activation completes.
func rollback(_abilities: GameAbilities, _grant: GameAbilityGrant, _request: GameAbilityActivationRequest, _prepared: Variant) -> void:
	pass

## Applies an optional gameplay refund after a committed execution is cancelled.
func refund(_abilities: GameAbilities, _grant: GameAbilityGrant, _execution: GameAbilityExecution, _prepared: Variant) -> void:
	pass

## Returns whether this cost resource is correctly configured.
func is_valid() -> bool:
	return true
