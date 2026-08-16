@tool
extends Resource
## Immutable effect-definition data describing one meter current-value change.
##
## The runtime applies [member delta] once per active stack on initial execution
## and on periodic ticks according to the owning [GameEffectDefinition].
class_name GameEffectMeterOperationSpec

# ======== EXPORT =========
@export var meter_id: StringName = &""
@export var delta: float = 0.0

# ====== PUBLIC ========
## Returns validation failures for authoring tools and parent definitions.
func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if meter_id.is_empty():
		errors.append("Meter operation requires a non-empty meter_id.")
	if is_nan(delta) or is_inf(delta):
		errors.append("Meter operation delta must be a finite number.")
	return errors

## Returns whether this meter operation can be consumed by effect runtime code.
func is_valid() -> bool:
	return get_validation_errors().is_empty()
