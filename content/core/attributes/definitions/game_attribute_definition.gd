@tool
extends Resource
class_name GameAttributeDefinition

# ======= ENUMS =========
enum ClampPolicy { NONE, MINIMUM, MAXIMUM, RANGE }

# ======== EXPORT =========
@export var attribute_id: StringName = &""
@export var display_name: String = ""
@export_multiline var debug_description: String = ""
@export var default_base: float = 0.0
@export var clamp_policy: ClampPolicy = ClampPolicy.NONE
@export var minimum: float = 0.0
@export var maximum: float = 0.0
@export_range(0, 8, 1) var display_precision: int = 2
@export var save_base: bool = true
@export var category_tags: Array[StringName] = []

# ====== PUBLIC ========
func is_valid() -> bool:
	if attribute_id.is_empty():
		return false
	return clamp_policy != ClampPolicy.RANGE or minimum <= maximum

func clamp_value(value: float) -> float:
	match clamp_policy:
		ClampPolicy.MINIMUM:
			return maxf(value, minimum)
		ClampPolicy.MAXIMUM:
			return minf(value, maximum)
		ClampPolicy.RANGE:
			return clampf(value, minimum, maximum)
		_:
			return value
