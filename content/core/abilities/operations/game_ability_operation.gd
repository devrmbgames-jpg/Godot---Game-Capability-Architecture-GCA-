@tool
extends Resource
## Virtual contract for one step in an ability execution sequence.
##
## Operations receive the owning [GameAbilities] feature and current
## [GameAbilityExecution], return structured results, and may provide cancellation
## cleanup when waiting asynchronously.
class_name GameAbilityOperation

# ======== EXPORT =========
@export var debug_label: String = ""
@export var continue_on_failure: bool = false

# ====== PUBLIC ========
## Executes this operation and returns its structured outcome.
func execute(_abilities: GameAbilities, _execution: GameAbilityExecution) -> GameCommandResult:
	return GameCommandResult.success_unchanged(&"ability_operation_noop")

## Cancels pending operation work for [param _execution].
func cancel(_abilities: GameAbilities, _execution: GameAbilityExecution, _reason: StringName) -> void:
	pass

## Returns whether execution must wait for an external completion signal or token.
func is_async() -> bool:
	return false

## Returns whether this operation resource is correctly configured.
func is_valid() -> bool:
	return true
