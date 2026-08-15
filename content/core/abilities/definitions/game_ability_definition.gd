@tool
extends Resource
## Immutable data-driven definition of an ability.
##
## Declares owner requirements, costs, cooldowns, concurrency channels,
## operations, persistence hints, and validation rules. Owner-specific data lives
## in [GameAbilityGrant]; activation state lives in [GameAbilityExecution].
class_name GameAbilityDefinition

# ======= ENUMS =========
enum GrantSelectionPolicy { HIGHEST_LEVEL, SOURCE_PRIORITY, FIRST_GRANTED }
enum RetriggerPolicy { DENY, RESTART, ALLOW_PARALLEL }
enum ConflictPolicy { DENY_NEW, CANCEL_EXISTING, QUEUE_NEW, ALLOW_PARALLEL }
enum SaveExecutionPolicy { CANCEL_ON_LOAD, COMPLETE_BEFORE_SAVE, DISALLOW_SAVE }

# ======== EXPORT =========
@export var ability_id: StringName = &""
@export var display_name: String = ""
@export_multiline var debug_description: String = ""
@export var ability_tags: Array[StringName] = []
@export var required_owner_capabilities: Array[StringName] = []
@export var required_owner_tags: Array[StringName] = []
@export var blocked_owner_tags: Array[StringName] = []
@export var granted_tags_during_execution: Array[StringName] = []
@export var requirements: Array[GameAbilityRequirement] = []
@export var costs: Array[GameAbilityCost] = []
@export_range(0.0, 86400.0, 0.01) var cooldown_duration: float = 0.0
@export var cooldown_key: StringName = &""
@export var cooldown_groups: Array[StringName] = []
@export var occupied_channels: Array[StringName] = []
@export var conflict_policy: ConflictPolicy = ConflictPolicy.DENY_NEW
@export var retrigger_policy: RetriggerPolicy = RetriggerPolicy.DENY
@export var operations: Array[GameAbilityOperation] = []
@export var passive: bool = false
@export var persist_grant: bool = false
@export var persist_cooldown: bool = false
@export var save_execution_policy: SaveExecutionPolicy = SaveExecutionPolicy.CANCEL_ON_LOAD
@export_range(1, 1000, 1) var schema_version: int = 1

# ====== PUBLIC ========
## Returns the explicit cooldown key or falls back to [member ability_id].
func get_resolved_cooldown_key() -> StringName:
	return cooldown_key if not cooldown_key.is_empty() else ability_id

## Returns whether the definition and all nested policies are configured correctly.
func is_valid() -> bool:
	if ability_id.is_empty() or cooldown_duration < 0.0 or schema_version < 1:
		return false
	if not passive and operations.is_empty():
		return false
	for requirement: GameAbilityRequirement in requirements:
		if requirement == null or not requirement.is_valid():
			return false
	for cost: GameAbilityCost in costs:
		if cost == null or not cost.is_valid():
			return false
	for operation: GameAbilityOperation in operations:
		if operation == null or not operation.is_valid():
			return false
	return true
