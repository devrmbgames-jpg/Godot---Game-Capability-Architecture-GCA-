@tool
extends Resource
class_name GameMeterDefinition

# ======= ENUMS =========
enum InitialPolicy { EMPTY, FULL, FIXED }
enum MaximumPolicy { CONSTANT, ATTRIBUTE }
enum MaximumChangePolicy { KEEP_CURRENT, KEEP_PERCENTAGE, ADJUST_BY_DELTA, CLAMP_ONLY }

# ======== EXPORT =========
@export var meter_id: StringName = &""
@export var initial_policy: InitialPolicy = InitialPolicy.FULL
@export var initial_value: float = 0.0
@export var maximum_policy: MaximumPolicy = MaximumPolicy.CONSTANT
@export var constant_maximum: float = 100.0
@export var maximum_attribute_id: StringName = &""
@export var minimum: float = 0.0
@export var maximum_change_policy: MaximumChangePolicy = MaximumChangePolicy.CLAMP_ONLY
@export var depletion_threshold: float = 0.0
@export var save_current: bool = true

# ====== PUBLIC ========
func is_valid() -> bool:
	if meter_id.is_empty(): return false
	if maximum_policy == MaximumPolicy.ATTRIBUTE: return not maximum_attribute_id.is_empty()
	return constant_maximum >= minimum
