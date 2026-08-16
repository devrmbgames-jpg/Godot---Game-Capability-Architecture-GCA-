@tool
extends RefCounted
## One-shot helper for converting legacy Dictionary-based effect operations to typed specs.
##
## This helper is tooling-only. Gameplay runtime must consume typed effect specs and must
## not use this class as a backwards-compatible Dictionary loader. A migration report with
## [code]ok == false[/code] must not be persisted as a migrated effect.
class_name GameEffectLegacyMigrator

# ======= CONSTS =========
const ATTRIBUTE_MODIFIER_KEYS: Array[StringName] = [
	&"attribute_id",
	&"operation",
	&"magnitude",
	&"priority",
]
const METER_OPERATION_KEYS: Array[StringName] = [
	&"meter_id",
	&"delta",
]

# ====== HELPERS ========
static func _read_legacy_value(legacy: Dictionary, key: StringName, fallback: Variant) -> Variant:
	if legacy.has(key):
		return legacy[key]
	var string_key: String = String(key)
	if legacy.has(string_key):
		return legacy[string_key]
	return fallback

static func _append_unknown_key_errors(legacy: Dictionary, allowed_keys: Array[StringName], errors: PackedStringArray) -> void:
	for raw_key: Variant in legacy.keys():
		if not (raw_key is StringName or raw_key is String):
			errors.append("Unsupported non-string legacy key '%s'." % str(raw_key))
			continue
		var key: StringName = StringName(raw_key)
		if not allowed_keys.has(key):
			errors.append("Unknown legacy key '%s'; migration refuses to drop it silently." % key)

static func _append_spec_errors(prefix: String, spec_errors: PackedStringArray, errors: PackedStringArray) -> void:
	for message: String in spec_errors:
		errors.append("%s: %s" % [prefix, message])

# ====== PUBLIC ========
## Converts one legacy attribute modifier Dictionary using the exact historical fallbacks.
## Missing fields materialize as: empty attribute ID, ADD, 0.0 magnitude, and priority 0.
## Unknown fields or invalid value types make the returned report unsuccessful.
static func migrate_attribute_modifier(legacy: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	_append_unknown_key_errors(legacy, ATTRIBUTE_MODIFIER_KEYS, errors)
	var spec := GameEffectAttributeModifierSpec.new()

	var attribute_value: Variant = _read_legacy_value(legacy, &"attribute_id", &"")
	if attribute_value is StringName or attribute_value is String:
		spec.attribute_id = StringName(attribute_value)
	else:
		errors.append("attribute_id must be StringName or String, got %s." % type_string(typeof(attribute_value)))

	var operation_value: Variant = _read_legacy_value(legacy, &"operation", GameAttributeModifier.Operation.ADD)
	if operation_value is int:
		spec.set(&"operation", int(operation_value))
	else:
		errors.append("operation must be an integer GameAttributeModifier.Operation value, got %s." % type_string(typeof(operation_value)))

	var magnitude_value: Variant = _read_legacy_value(legacy, &"magnitude", 0.0)
	if magnitude_value is int or magnitude_value is float:
		spec.magnitude = float(magnitude_value)
	else:
		errors.append("magnitude must be numeric, got %s." % type_string(typeof(magnitude_value)))

	var priority_value: Variant = _read_legacy_value(legacy, &"priority", 0)
	if priority_value is int:
		spec.priority = int(priority_value)
	else:
		errors.append("priority must be int, got %s." % type_string(typeof(priority_value)))

	_append_spec_errors("Migrated attribute modifier", spec.get_validation_errors(), errors)
	return {
		"ok": errors.is_empty(),
		"spec": spec,
		"errors": errors,
	}

## Converts one legacy meter-operation Dictionary using the exact historical fallbacks.
## Missing fields materialize as: empty meter ID and delta 0.0. Unknown fields or invalid
## value types make the returned report unsuccessful.
static func migrate_meter_operation(legacy: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	_append_unknown_key_errors(legacy, METER_OPERATION_KEYS, errors)
	var spec := GameEffectMeterOperationSpec.new()

	var meter_value: Variant = _read_legacy_value(legacy, &"meter_id", &"")
	if meter_value is StringName or meter_value is String:
		spec.meter_id = StringName(meter_value)
	else:
		errors.append("meter_id must be StringName or String, got %s." % type_string(typeof(meter_value)))

	var delta_value: Variant = _read_legacy_value(legacy, &"delta", 0.0)
	if delta_value is int or delta_value is float:
		spec.delta = float(delta_value)
	else:
		errors.append("delta must be numeric, got %s." % type_string(typeof(delta_value)))

	_append_spec_errors("Migrated meter operation", spec.get_validation_errors(), errors)
	return {
		"ok": errors.is_empty(),
		"spec": spec,
		"errors": errors,
	}

## Converts complete legacy operation arrays without mutating the source Dictionaries.
## The result is safe to persist only when [code]ok[/code] is true; any element failure is
## retained in the indexed error report instead of silently dropping authored data.
static func migrate_operation_arrays(legacy_attribute_modifiers: Array[Dictionary], legacy_meter_operations: Array[Dictionary]) -> Dictionary:
	var attribute_specs: Array[GameEffectAttributeModifierSpec] = []
	var meter_specs: Array[GameEffectMeterOperationSpec] = []
	var errors := PackedStringArray()

	for index: int in range(legacy_attribute_modifiers.size()):
		var report: Dictionary = migrate_attribute_modifier(legacy_attribute_modifiers[index])
		if bool(report.get("ok", false)):
			attribute_specs.append(report.get("spec") as GameEffectAttributeModifierSpec)
		else:
			var report_errors: PackedStringArray = report.get("errors", PackedStringArray())
			for message: String in report_errors:
				errors.append("attribute_modifiers[%d]: %s" % [index, message])

	for index: int in range(legacy_meter_operations.size()):
		var report: Dictionary = migrate_meter_operation(legacy_meter_operations[index])
		if bool(report.get("ok", false)):
			meter_specs.append(report.get("spec") as GameEffectMeterOperationSpec)
		else:
			var report_errors: PackedStringArray = report.get("errors", PackedStringArray())
			for message: String in report_errors:
				errors.append("meter_operations[%d]: %s" % [index, message])

	return {
		"ok": errors.is_empty(),
		"attribute_modifiers": attribute_specs,
		"meter_operations": meter_specs,
		"errors": errors,
	}
