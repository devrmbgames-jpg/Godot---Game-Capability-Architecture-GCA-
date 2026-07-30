@tool
extends Resource
class_name GameAbilityOperation

# ======== EXPORT =========
@export var debug_label: String = ""
@export var continue_on_failure: bool = false

# ====== PUBLIC ========
func execute(_abilities: GameAbilities, _execution: GameAbilityExecution) -> GameCommandResult:
	return GameCommandResult.success_unchanged(&"ability_operation_noop")

func cancel(_abilities: GameAbilities, _execution: GameAbilityExecution, _reason: StringName) -> void:
	pass

func is_async() -> bool:
	return false

func is_valid() -> bool:
	return true
