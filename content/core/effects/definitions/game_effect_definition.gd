@tool
extends Resource
## Immutable definition of a gameplay effect.
##
## Describes lifetime, periodic execution, stacking, tag grants, attribute
## modifiers, meter operations, and persistence hints. Per-target runtime state
## is stored in [GameActiveEffect].
class_name GameEffectDefinition

# ======= CONSTS =========
const LEGACY_SCHEMA_VERSION: int = 1
const CURRENT_SCHEMA_VERSION: int = 2

# ======= ENUMS =========
enum DurationPolicy { INSTANT, DURATION, INFINITE }
enum StackingPolicy { REJECT_DUPLICATE, REFRESH_DURATION, ADD_STACK, INDEPENDENT, REPLACE_OLDER }

# ======== EXPORT =========
@export var schema_version: int = CURRENT_SCHEMA_VERSION
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
@export var attribute_modifiers: Array[GameEffectAttributeModifierSpec] = []
@export var meter_operations: Array[GameEffectMeterOperationSpec] = []
@export var persistent: bool = false
@export_multiline var debug_description: String = ""

# ====== PUBLIC ========
## Returns authoring validation failures, including invalid nested operation specs.
func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var effect_label: String = String(effect_id) if not effect_id.is_empty() else "<empty>"
	if schema_version != CURRENT_SCHEMA_VERSION:
		errors.append("Effect '%s': schema_version %d is unsupported; expected %d." % [effect_label, schema_version, CURRENT_SCHEMA_VERSION])
	if effect_id.is_empty():
		errors.append("Effect '<empty>': effect_id must not be empty.")
	if duration_policy == DurationPolicy.DURATION and duration <= 0.0:
		errors.append("Effect '%s': finite duration must be greater than zero." % effect_label)
	if is_nan(duration) or is_inf(duration):
		errors.append("Effect '%s': duration must be a finite number." % effect_label)
	if period < 0.0:
		errors.append("Effect '%s': period must not be negative." % effect_label)
	if is_nan(period) or is_inf(period):
		errors.append("Effect '%s': period must be a finite number." % effect_label)
	if stack_limit < 1:
		errors.append("Effect '%s': stack_limit must be at least one." % effect_label)

	for index: int in attribute_modifiers.size():
		var modifier_spec: GameEffectAttributeModifierSpec = attribute_modifiers[index]
		if modifier_spec == null:
			errors.append("Effect '%s': attribute modifier #%d is null." % [effect_label, index])
			continue
		var target_label: String = String(modifier_spec.attribute_id) if not modifier_spec.attribute_id.is_empty() else "<empty>"
		for nested_error: String in modifier_spec.get_validation_errors():
			errors.append("Effect '%s': attribute modifier #%d target '%s': %s" % [effect_label, index, target_label, nested_error])

	for index: int in meter_operations.size():
		var meter_operation: GameEffectMeterOperationSpec = meter_operations[index]
		if meter_operation == null:
			errors.append("Effect '%s': meter operation #%d is null." % [effect_label, index])
			continue
		var target_label: String = String(meter_operation.meter_id) if not meter_operation.meter_id.is_empty() else "<empty>"
		for nested_error: String in meter_operation.get_validation_errors():
			errors.append("Effect '%s': meter operation #%d target '%s': %s" % [effect_label, index, target_label, nested_error])
	return errors

## Returns whether the effect and every nested operation spec are valid.
func is_valid() -> bool:
	return get_validation_errors().is_empty()
