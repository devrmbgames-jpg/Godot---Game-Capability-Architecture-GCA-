@tool
extends RefCounted
class_name GameDataSchemaRegistry

# ======= CONSTS =========
const GENERIC_ID_PROPERTIES: Array[StringName] = [
	&"tag_id",
	&"attribute_id",
	&"meter_id",
	&"effect_id",
	&"ability_id",
	&"offer_id",
	&"cue_id",
	&"spawn_id",
	&"archetype_id",
	&"definition_id",
	&"id",
]

const SCHEMAS: Dictionary = {
	&"GameAttributeDefinition": {
		"title": "Attributes",
		"singular": "Attribute",
		"id_property": &"attribute_id",
		"display_property": &"display_name",
		"default_folder": "res://content/gameplay/attributes",
		"file_prefix": "attr_",
		"script_path": "res://content/core/attributes/definitions/game_attribute_definition.gd",
		"columns": [
			{"property": &"attribute_id", "title": "ID", "editable": true, "kind": &"text"},
			{"property": &"display_name", "title": "Name", "editable": true, "kind": &"text"},
			{"property": &"default_base", "title": "Default", "editable": true, "kind": &"float"},
			{"property": &"clamp_policy", "title": "Clamp", "editable": true, "kind": &"enum", "options": ["None", "Minimum", "Maximum", "Range"]},
			{"property": &"minimum", "title": "Min", "editable": true, "kind": &"float"},
			{"property": &"maximum", "title": "Max", "editable": true, "kind": &"float"},
			{"property": &"save_base", "title": "Save", "editable": true, "kind": &"bool"},
			{"property": &"category_tags", "title": "Categories", "editable": true, "kind": &"string_names"},
		],
	},
	&"GameMeterDefinition": {
		"title": "Meters",
		"singular": "Meter",
		"id_property": &"meter_id",
		"display_property": &"meter_id",
		"default_folder": "res://content/gameplay/meters",
		"file_prefix": "meter_",
		"script_path": "res://content/core/meters/definitions/game_meter_definition.gd",
		"columns": [
			{"property": &"meter_id", "title": "ID", "editable": true, "kind": &"text"},
			{"property": &"initial_policy", "title": "Initial", "editable": true, "kind": &"enum", "options": ["Empty", "Full", "Fixed"]},
			{"property": &"initial_value", "title": "Initial Value", "editable": true, "kind": &"float"},
			{"property": &"maximum_policy", "title": "Maximum", "editable": true, "kind": &"enum", "options": ["Constant", "Attribute"]},
			{"property": &"constant_maximum", "title": "Max Value", "editable": true, "kind": &"float"},
			{"property": &"maximum_attribute_id", "title": "Max Attribute", "editable": true, "kind": &"text"},
			{"property": &"minimum", "title": "Min", "editable": true, "kind": &"float"},
			{"property": &"depletion_threshold", "title": "Depletion", "editable": true, "kind": &"float"},
			{"property": &"save_current", "title": "Save", "editable": true, "kind": &"bool"},
		],
	},
	&"GameEffectDefinition": {
		"title": "Effects",
		"singular": "Effect",
		"id_property": &"effect_id",
		"display_property": &"effect_id",
		"default_folder": "res://content/gameplay/effects",
		"file_prefix": "effect_",
		"script_path": "res://content/core/effects/definitions/game_effect_definition.gd",
		"columns": [
			{"property": &"effect_id", "title": "ID", "editable": true, "kind": &"text"},
			{"property": &"duration_policy", "title": "Duration Policy", "editable": true, "kind": &"enum", "options": ["Instant", "Duration", "Infinite"]},
			{"property": &"duration", "title": "Duration", "editable": true, "kind": &"float"},
			{"property": &"period", "title": "Period", "editable": true, "kind": &"float"},
			{"property": &"execute_period_on_apply", "title": "Tick On Apply", "editable": true, "kind": &"bool"},
			{"property": &"stacking_policy", "title": "Stacking", "editable": true, "kind": &"enum", "options": ["Reject", "Refresh", "Add Stack", "Independent", "Replace Older"]},
			{"property": &"stack_limit", "title": "Stack Limit", "editable": true, "kind": &"int"},
			{"property": &"granted_tags", "title": "Granted Tags", "editable": true, "kind": &"string_names"},
			{"property": &"persistent", "title": "Persistent", "editable": true, "kind": &"bool"},
		],
	},
	&"GameAbilityDefinition": {
		"title": "Abilities",
		"singular": "Ability",
		"id_property": &"ability_id",
		"display_property": &"display_name",
		"default_folder": "res://content/gameplay/abilities",
		"file_prefix": "ability_",
		"script_path": "res://content/core/abilities/definitions/game_ability_definition.gd",
		"columns": [
			{"property": &"ability_id", "title": "ID", "editable": true, "kind": &"text"},
			{"property": &"display_name", "title": "Name", "editable": true, "kind": &"text"},
			{"property": &"passive", "title": "Passive", "editable": true, "kind": &"bool"},
			{"property": &"cooldown_duration", "title": "Cooldown", "editable": true, "kind": &"float"},
			{"property": &"cooldown_key", "title": "Cooldown Key", "editable": true, "kind": &"text"},
			{"property": &"occupied_channels", "title": "Channels", "editable": true, "kind": &"string_names"},
			{"property": &"conflict_policy", "title": "Conflict", "editable": true, "kind": &"enum", "options": ["Deny New", "Cancel Existing", "Queue New", "Allow Parallel"]},
			{"property": &"persist_grant", "title": "Save Grant", "editable": true, "kind": &"bool"},
			{"property": &"persist_cooldown", "title": "Save Cooldown", "editable": true, "kind": &"bool"},
			{"property": &"schema_version", "title": "Schema", "editable": true, "kind": &"int"},
		],
	},
}

# ====== HELPERS ========
static func _has_property(resource: Resource, property_name: StringName) -> bool:
	for property_data: Dictionary in resource.get_property_list():
		if StringName(property_data.get("name", &"")) == property_name:
			return true
	return false

# ====== PUBLIC ========
static func get_schema(resource_class: StringName) -> Dictionary:
	return (SCHEMAS.get(resource_class, {}) as Dictionary).duplicate(true)

static func get_supported_classes() -> Array[StringName]:
	var result: Array[StringName] = []
	for resource_class: StringName in SCHEMAS.keys():
		result.append(resource_class)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result

static func detect_resource_class(resource: Resource) -> StringName:
	if resource == null:
		return &""
	var script: Script = resource.get_script() as Script
	if script != null:
		var global_name: StringName = script.get_global_name()
		if not global_name.is_empty():
			return global_name
	return StringName(resource.get_class())

static func detect_id_property(resource: Resource, resource_class: StringName = &"") -> StringName:
	var schema: Dictionary = get_schema(resource_class)
	var configured_property: StringName = schema.get("id_property", &"")
	if not configured_property.is_empty() and _has_property(resource, configured_property):
		return configured_property
	for property_name: StringName in GENERIC_ID_PROPERTIES:
		if _has_property(resource, property_name):
			return property_name
	return &""

static func is_indexable(resource: Resource) -> bool:
	var resource_class: StringName = detect_resource_class(resource)
	if SCHEMAS.has(resource_class):
		return true
	if not String(resource_class).begins_with("Game"):
		return false
	return not detect_id_property(resource, resource_class).is_empty()

static func get_resource_id(resource: Resource, resource_class: StringName = &"") -> StringName:
	var resolved_class: StringName = resource_class if not resource_class.is_empty() else detect_resource_class(resource)
	var id_property: StringName = detect_id_property(resource, resolved_class)
	if id_property.is_empty():
		return &""
	return StringName(str(resource.get(id_property)))

static func get_display_name(resource: Resource, resource_class: StringName = &"") -> String:
	var resolved_class: StringName = resource_class if not resource_class.is_empty() else detect_resource_class(resource)
	var schema: Dictionary = get_schema(resolved_class)
	var display_property: StringName = schema.get("display_property", &"")
	if not display_property.is_empty() and _has_property(resource, display_property):
		var value: String = str(resource.get(display_property))
		if not value.is_empty():
			return value
	return String(get_resource_id(resource, resolved_class))

static func get_category_title(resource_class: StringName) -> String:
	var schema: Dictionary = get_schema(resource_class)
	return str(schema.get("title", resource_class)) if not schema.is_empty() else "Other Resources"

static func get_columns(resource_class: StringName) -> Array[Dictionary]:
	var schema: Dictionary = get_schema(resource_class)
	var result: Array[Dictionary] = []
	for column_data: Dictionary in schema.get("columns", []):
		result.append(column_data.duplicate(true))
	return result

static func get_creation_schema(resource_class: StringName) -> Dictionary:
	return get_schema(resource_class)
