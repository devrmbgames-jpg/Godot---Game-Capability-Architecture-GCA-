@tool
extends Resource
## Immutable effect-definition data describing one attribute modifier.
##
## The runtime applies [member magnitude] once per active stack while preserving
## ownership through [GameAttributeModifier] handles. This resource contains no
## per-target runtime state.
class_name GameEffectAttributeModifierSpec

# ======== EXPORT =========
@export var attribute_id: StringName = &""
@export var operation: GameAttributeModifier.Operation = GameAttributeModifier.Operation.ADD
@export var magnitude: float = 0.0
@export var priority: int = 0

# ====== HELPERS ========
func _is_operation_valid() -> bool:
	match operation:
		GameAttributeModifier.Operation.ADD, GameAttributeModifier.Operation.INCREASE:
			return true
		_:
			return false

# ====== PUBLIC ========
## Returns validation failures for authoring tools and parent definitions.
func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if attribute_id.is_empty():
		errors.append("Attribute modifier requires a non-empty attribute_id.")
	if not _is_operation_valid():
		errors.append("Attribute modifier operation is invalid.")
	if is_nan(magnitude) or is_inf(magnitude):
		errors.append("Attribute modifier magnitude must be a finite number.")
	return errors

## Returns whether this modifier spec can be consumed by effect runtime code.
func is_valid() -> bool:
	return not attribute_id.is_empty() and _is_operation_valid() and not is_nan(magnitude) and not is_inf(magnitude)
