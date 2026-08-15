@tool
extends GameFeature
## Feature that owns an object's runtime attributes and modifier handles.
##
## Provides query and mutation capabilities, batches change notifications in
## transactions, and publishes one deterministic [code]attribute_changed[/code]
## local event for each affected attribute.
class_name GameAttributes

# ======== EXPORT =========
@export var definitions: Array[GameAttributeDefinition] = []
@export var base_overrides: Dictionary = {}

# ======== PRIVATE VAR ======
var _values: Dictionary = {}
var _modifiers_by_handle: Dictionary = {}
var _handle_counter: int = 0
var _transaction_depth: int = 0
var _changed_ids: Dictionary = {}

# ======= OVERRIDE =======
## Configures the feature ID and exclusive attribute capabilities.
func _init() -> void:
	feature_id = &"object.attributes"
	if provided_capabilities.is_empty():
		for capability_id: StringName in [GameCapabilityIds.ATTRIBUTES_PROVIDER, GameCapabilityIds.ATTRIBUTES_QUERY, GameCapabilityIds.ATTRIBUTES_MODIFY]:
			var spec := GameCapabilitySpec.new()
			spec.capability_id = capability_id
			spec.cardinality = GameCapabilityCardinality.Type.EXCLUSIVE
			provided_capabilities.append(spec)

## Returns editor warnings for invalid or duplicated attribute definitions.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = super()
	var ids: Dictionary = {}
	for definition: GameAttributeDefinition in definitions:
		if definition == null or not definition.is_valid():
			warnings.append("GameAttributes contains an invalid definition.")
		elif ids.has(definition.attribute_id):
			warnings.append("Duplicate attribute ID '%s'." % definition.attribute_id)
		else:
			ids[definition.attribute_id] = true
	return warnings

## Builds runtime values from immutable definitions during feature initialization.
func on_game_initialize() -> GameCommandResult:
	_values.clear()
	_modifiers_by_handle.clear()
	_handle_counter = 0
	for definition: GameAttributeDefinition in definitions:
		if definition == null or not definition.is_valid() or _values.has(definition.attribute_id):
			return GameCommandResult.configuration_error(&"invalid_attribute_configuration", "Attribute definitions are invalid or duplicated.")
		_values[definition.attribute_id] = GameAttributeValue.new(definition, base_overrides.get(definition.attribute_id))
	return GameCommandResult.success_changed(&"attributes_initialized")

## Invalidates owned modifiers and releases all runtime state.
func on_game_shutdown() -> void:
	for modifier: GameAttributeModifier in _modifiers_by_handle.values(): modifier.invalidate()
	_values.clear()
	_modifiers_by_handle.clear()

# ====== HELPERS ========
func _mark_changed(attribute_id: StringName) -> void:
	_changed_ids[attribute_id] = true
	if _transaction_depth == 0: _flush_events()

func _flush_events() -> void:
	var context: GameObjectContext = get_context()
	if context == null: return
	var ids: Array = _changed_ids.keys(); ids.sort()
	for attribute_id: StringName in ids:
		var execution_context: GameExecutionContext = context.create_root_execution_context(&"attribute_changed", "Attribute changed")
		publish_local_event(GameLocalEvent.new(&"attribute_changed", context.get_object_handle(), execution_context, {"attribute_id": attribute_id, "value": get_value(attribute_id)}))
	_changed_ids.clear()

# ====== PUBLIC ========
## Starts a nested attribute transaction and postpones change events.
func begin_transaction() -> void: _transaction_depth += 1
## Ends one transaction level and publishes accumulated changes at depth zero.
func end_transaction() -> void:
	_transaction_depth = maxi(0, _transaction_depth - 1)
	if _transaction_depth == 0: _flush_events()
## Returns whether this component owns [param attribute_id].
func has_attribute(attribute_id: StringName) -> bool: return _values.has(attribute_id)
## Returns the final value of [param attribute_id], or [param fallback] when absent.
func get_value(attribute_id: StringName, fallback: float = 0.0) -> float:
	return (_values[attribute_id] as GameAttributeValue).get_final() if _values.has(attribute_id) else fallback
## Replaces an attribute's base layer and returns a structured command result.
func set_base(attribute_id: StringName, value: float) -> GameCommandResult:
	if not _values.has(attribute_id): return GameCommandResult.rejected_permanent(&"unknown_attribute", "Unknown attribute '%s'." % attribute_id)
	(_values[attribute_id] as GameAttributeValue).set_base(value); _mark_changed(attribute_id)
	return GameCommandResult.success_changed(&"attribute_base_changed", value)
## Creates and registers a modifier for [param attribute_id].
## Returns [code]null[/code] when the target or source ID is invalid.
func add_modifier(attribute_id: StringName, operation: GameAttributeModifier.Operation, magnitude: float, source_id: StringName, owning_effect_handle: int = 0, priority: int = 0) -> GameAttributeModifier:
	if not _values.has(attribute_id) or source_id.is_empty(): return null
	_handle_counter += 1
	var modifier := GameAttributeModifier.new(_handle_counter, attribute_id, operation, magnitude, source_id, owning_effect_handle, priority, _handle_counter)
	_modifiers_by_handle[_handle_counter] = modifier
	(_values[attribute_id] as GameAttributeValue).add_modifier(modifier)
	_mark_changed(attribute_id)
	return modifier
## Removes one modifier by handle and reports whether state changed.
func remove_modifier(handle_id: int) -> bool:
	if not _modifiers_by_handle.has(handle_id): return false
	var modifier: GameAttributeModifier = _modifiers_by_handle[handle_id]
	var removed: bool = (_values[modifier.get_target_attribute_id()] as GameAttributeValue).remove_modifier(handle_id)
	_modifiers_by_handle.erase(handle_id)
	if removed: _mark_changed(modifier.get_target_attribute_id())
	return removed
## Removes every modifier owned by [param effect_handle].
## Returns the number of matching handles processed.
func remove_modifiers_by_effect(effect_handle: int) -> int:
	var handles: Array[int] = []
	for modifier: GameAttributeModifier in _modifiers_by_handle.values():
		if modifier.get_owning_effect_handle() == effect_handle: handles.append(modifier.get_handle_id())
	for handle_id: int in handles: remove_modifier(handle_id)
	return handles.size()
## Returns a diagnostic snapshot keyed by attribute ID.
func get_debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for attribute_id: StringName in _values.keys(): snapshot[attribute_id] = (_values[attribute_id] as GameAttributeValue).get_debug_snapshot()
	return snapshot
