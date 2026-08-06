@tool
extends Resource
## Immutable definition of a gameplay effect.
##
## Describes lifetime, periodic execution, stacking, tag grants, attribute
## modifiers, meter operations, and persistence hints. Per-target runtime state
## is stored in [GameActiveEffect].
class_name GameEffectDefinition

# ======= ENUMS =========
enum DurationPolicy { INSTANT, DURATION, INFINITE }
enum StackingPolicy { REJECT_DUPLICATE, REFRESH_DURATION, ADD_STACK, INDEPENDENT, REPLACE_OLDER }

# ======== EXPORT =========
@export var effect_id: StringName = &""
@export var duration_policy: DurationPolicy = DurationPolicy.INSTANT
@export var duration: float = 0.0
@export var period: float = 0.0
@export var execute_period_on_apply: bool = false
@export var stacking_policy: StackingPolicy = StackingPolicy.REJECT_DUPLICATE
@export_range(1, 999, 1) var stack_limit: int = 1
@export var required_target_tags: Array[StringName] = []
@export var blocked_target_tags: Array[StringName] = []
@export var granted_tags: Array[StringName] = []
@export var attribute_modifiers: Array[Dictionary] = []
@export var meter_operations: Array[Dictionary] = []
@export var persistent: bool = false
@export_multiline var debug_description: String = ""

# ====== PUBLIC ========
## Returns whether the effect ID, duration, period, and stack limit are valid.
func is_valid() -> bool:
	if effect_id.is_empty(): return false
	if duration_policy == DurationPolicy.DURATION and duration <= 0.0: return false
	if period < 0.0 or stack_limit < 1: return false
	return true
