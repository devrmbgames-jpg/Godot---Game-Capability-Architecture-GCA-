@tool
extends RefCounted
## Validates indexed GCA definitions and produces structured editor issues.
##
## The validator checks common ID and file rules plus cross-definition references for meters,
## effects, and abilities, then writes issue summaries back into [GameDataIndex].
class_name GameDataValidator

# ======= CONSTS =========
const SEVERITY_ERROR: StringName = &"error"
const SEVERITY_WARNING: StringName = &"warning"

# ====== HELPERS ========
func _issue(severity: StringName, code: StringName, message: String, property_name: StringName = &"") -> Dictionary:
	return {
		"severity": severity,
		"code": code,
		"message": message,
		"property": property_name,
	}

func _build_id_set(records: Array[Dictionary], resource_class: StringName) -> Dictionary:
	var result: Dictionary = {}
	for record: Dictionary in records:
		if record.get("resource_class", &"") != resource_class:
			continue
		var resource_id: StringName = record.get("id", &"")
		if not resource_id.is_empty():
			result[resource_id] = true
	return result

func _validate_common(record: Dictionary, duplicate_counts: Dictionary) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var resource: Resource = record.get("resource") as Resource
	var resource_class: StringName = record.get("resource_class", &"")
	var resource_id: StringName = record.get("id", &"")
	var path: String = str(record.get("path", ""))
	if resource == null:
		issues.append(_issue(SEVERITY_ERROR, &"resource_load_failed", "Resource could not be loaded."))
		return issues
	if resource_id.is_empty():
		issues.append(_issue(SEVERITY_ERROR, &"missing_definition_id", "Definition requires a stable non-empty ID."))
	var duplicate_key: String = "%s::%s" % [resource_class, resource_id]
	if not resource_id.is_empty() and int(duplicate_counts.get(duplicate_key, 0)) > 1:
		issues.append(_issue(SEVERITY_ERROR, &"duplicate_definition_id", "ID '%s' is duplicated inside %s." % [resource_id, resource_class]))
	if resource.has_method("is_valid"):
		var valid_result: Variant = resource.call("is_valid")
		if valid_result is bool and not bool(valid_result):
			issues.append(_issue(SEVERITY_ERROR, &"definition_invalid", "The definition rejected its current configuration."))
	var schema: Dictionary = GameDataSchemaRegistry.get_schema(resource_class)
	if not schema.is_empty():
		var expected_prefix: String = str(schema.get("file_prefix", ""))
		var file_name: String = path.get_file()
		if not expected_prefix.is_empty() and not file_name.begins_with(expected_prefix):
			issues.append(_issue(SEVERITY_WARNING, &"unexpected_file_prefix", "File should use prefix '%s'." % expected_prefix))
	return issues

func _validate_meter(resource: Resource, attribute_ids: Dictionary) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var maximum_policy: int = int(resource.get(&"maximum_policy"))
	var maximum_attribute_id: StringName = StringName(resource.get(&"maximum_attribute_id"))
	if maximum_policy == 1:
		if maximum_attribute_id.is_empty():
			issues.append(_issue(SEVERITY_ERROR, &"missing_meter_maximum_attribute", "Attribute-backed meter requires maximum_attribute_id.", &"maximum_attribute_id"))
		elif not attribute_ids.has(maximum_attribute_id):
			issues.append(_issue(SEVERITY_ERROR, &"unknown_meter_maximum_attribute", "Attribute '%s' is not indexed." % maximum_attribute_id, &"maximum_attribute_id"))
	var minimum: float = float(resource.get(&"minimum"))
	var constant_maximum: float = float(resource.get(&"constant_maximum"))
	if maximum_policy == 0 and constant_maximum < minimum:
		issues.append(_issue(SEVERITY_ERROR, &"meter_maximum_below_minimum", "Constant maximum cannot be below minimum.", &"constant_maximum"))
	return issues

func _validate_effect(resource: Resource, attribute_ids: Dictionary, meter_ids: Dictionary) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var effect: GameEffectDefinition = resource as GameEffectDefinition
	if effect == null:
		issues.append(_issue(SEVERITY_ERROR, &"effect_type_mismatch", "Indexed effect is not a GameEffectDefinition."))
		return issues

	for message: String in effect.get_validation_errors():
		issues.append(_issue(SEVERITY_ERROR, &"effect_definition_validation", message))

	for index: int in range(effect.attribute_modifiers.size()):
		var modifier_spec: GameEffectAttributeModifierSpec = effect.attribute_modifiers[index]
		if modifier_spec == null or modifier_spec.attribute_id.is_empty():
			continue
		if not attribute_ids.has(modifier_spec.attribute_id):
			issues.append(
				_issue(
					SEVERITY_ERROR,
					&"effect_modifier_unknown_attribute",
					"Attribute modifier %d references unknown attribute '%s'." % [index, modifier_spec.attribute_id],
					&"attribute_modifiers"
				)
			)

	for index: int in range(effect.meter_operations.size()):
		var operation_spec: GameEffectMeterOperationSpec = effect.meter_operations[index]
		if operation_spec == null or operation_spec.meter_id.is_empty():
			continue
		if not meter_ids.has(operation_spec.meter_id):
			issues.append(
				_issue(
					SEVERITY_ERROR,
					&"effect_operation_unknown_meter",
					"Meter operation %d references unknown meter '%s'." % [index, operation_spec.meter_id],
					&"meter_operations"
				)
			)
	return issues

func _validate_ability(resource: Resource) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var passive: bool = bool(resource.get(&"passive"))
	var operations: Array = resource.get(&"operations") as Array
	if not passive and operations.is_empty():
		issues.append(_issue(SEVERITY_ERROR, &"ability_has_no_operations", "Active ability requires at least one operation.", &"operations"))
	var cooldown_duration: float = float(resource.get(&"cooldown_duration"))
	if cooldown_duration < 0.0:
		issues.append(_issue(SEVERITY_ERROR, &"negative_ability_cooldown", "Cooldown cannot be negative.", &"cooldown_duration"))
	var required_capabilities: Array = resource.get(&"required_owner_capabilities") as Array
	for capability_value: Variant in required_capabilities:
		var capability_id: StringName = StringName(capability_value)
		if capability_id.is_empty():
			issues.append(_issue(SEVERITY_ERROR, &"empty_required_capability", "Required capability list contains an empty ID.", &"required_owner_capabilities"))
	var occupied_channels: Array = resource.get(&"occupied_channels") as Array
	for channel_value: Variant in occupied_channels:
		var channel_id: StringName = StringName(channel_value)
		if channel_id.is_empty():
			issues.append(_issue(SEVERITY_ERROR, &"empty_ability_channel", "Occupied channel list contains an empty ID.", &"occupied_channels"))
	return issues

func _validate_string_name_arrays(resource: Resource) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	for property_data: Dictionary in resource.get_property_list():
		var property_name: StringName = property_data.get("name", &"")
		if property_name.is_empty():
			continue
		var value: Variant = resource.get(property_name)
		if not value is Array:
			continue
		var array_value: Array = value as Array
		for index: int in array_value.size():
			if array_value[index] is StringName and StringName(array_value[index]).is_empty():
				issues.append(_issue(SEVERITY_WARNING, &"empty_id_in_array", "Array '%s' contains an empty ID at index %d." % [property_name, index], property_name))
	return issues

# ====== PUBLIC ========
## Validates every record in [param index], updates record issue counts, and returns a summary report.
func validate(index: GameDataIndex) -> Dictionary:
	var records: Array[Dictionary] = index.get_records()
	var duplicate_counts: Dictionary = {}
	for record: Dictionary in records:
		var resource_id: StringName = record.get("id", &"")
		var resource_class: StringName = record.get("resource_class", &"")
		if resource_id.is_empty():
			continue
		var duplicate_key: String = "%s::%s" % [resource_class, resource_id]
		duplicate_counts[duplicate_key] = int(duplicate_counts.get(duplicate_key, 0)) + 1
	var attribute_ids: Dictionary = _build_id_set(records, &"GameAttributeDefinition")
	var meter_ids: Dictionary = _build_id_set(records, &"GameMeterDefinition")
	var issues_by_path: Dictionary = {}
	var error_count: int = 0
	var warning_count: int = 0
	for record: Dictionary in records:
		var resource: Resource = record.get("resource") as Resource
		var resource_class: StringName = record.get("resource_class", &"")
		var issues: Array[Dictionary] = _validate_common(record, duplicate_counts)
		if resource != null:
			match resource_class:
				&"GameMeterDefinition":
					issues.append_array(_validate_meter(resource, attribute_ids))
				&"GameEffectDefinition":
					issues.append_array(_validate_effect(resource, attribute_ids, meter_ids))
				&"GameAbilityDefinition":
					issues.append_array(_validate_ability(resource))
			issues.append_array(_validate_string_name_arrays(resource))
		for issue: Dictionary in issues:
			match StringName(issue.get("severity", SEVERITY_WARNING)):
				SEVERITY_ERROR:
					error_count += 1
				SEVERITY_WARNING:
					warning_count += 1
		var path: String = str(record.get("path", ""))
		issues_by_path[path] = issues
		index.update_record_issues(path, issues)
	return {
		"issues_by_path": issues_by_path,
		"error_count": error_count,
		"warning_count": warning_count,
		"record_count": records.size(),
	}