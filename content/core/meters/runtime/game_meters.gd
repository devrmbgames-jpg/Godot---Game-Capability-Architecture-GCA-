@tool
extends GameFeature
## Feature that owns current-value meters for one gameplay object.
##
## Resolves optional attribute-backed maximums, updates them after attribute
## events, and publishes deterministic meter change, fill, and depletion events.
class_name GameMeters

# ======== EXPORT =========
@export var definitions: Array[GameMeterDefinition] = []

# ======== PRIVATE VAR ======
var _values: Dictionary = {}
var _attributes: GameAttributes = null

# ======= OVERRIDE =======
## Configures meter capabilities and the optional attributes dependency.
func _init() -> void:
	feature_id = &"object.meters"
	if provided_capabilities.is_empty():
		for capability_id: StringName in [GameCapabilityIds.METERS_PROVIDER, GameCapabilityIds.METERS_QUERY, GameCapabilityIds.METERS_MODIFY]:
			var spec := GameCapabilitySpec.new(); spec.capability_id = capability_id; spec.cardinality = GameCapabilityCardinality.Type.EXCLUSIVE; provided_capabilities.append(spec)
	if optional_dependencies.is_empty():
		var dependency := GameCapabilityDependency.new(); dependency.capability_id = GameCapabilityIds.ATTRIBUTES_QUERY; dependency.required = false; optional_dependencies.append(dependency)

## Builds runtime meter values and resolves configured maximum sources.
func on_game_initialize() -> GameCommandResult:
	_values.clear()
	_attributes = get_dependency(GameCapabilityIds.ATTRIBUTES_QUERY) as GameAttributes
	for definition: GameMeterDefinition in definitions:
		if definition == null or not definition.is_valid() or _values.has(definition.meter_id): return GameCommandResult.configuration_error(&"invalid_meter_configuration", "Meter definitions are invalid or duplicated.")
		var maximum: float = definition.constant_maximum
		if definition.maximum_policy == GameMeterDefinition.MaximumPolicy.ATTRIBUTE:
			if _attributes == null or not _attributes.has_attribute(definition.maximum_attribute_id): return GameCommandResult.configuration_error(&"unknown_meter_maximum_attribute", "Meter maximum attribute is unavailable.")
			maximum = _attributes.get_value(definition.maximum_attribute_id)
		_values[definition.meter_id] = GameMeterValue.new(definition, maximum)
	return GameCommandResult.success_changed(&"meters_initialized")

## Updates attribute-backed maximums after a local attribute change event.
func on_local_event(event: GameLocalEvent) -> void:
	if event.get_event_type_id() != &"attribute_changed": return
	var attribute_id: StringName = event.get_payload().get("attribute_id", &"")
	for meter: GameMeterValue in _values.values():
		var definition: GameMeterDefinition = meter.get_definition()
		if definition.maximum_policy == GameMeterDefinition.MaximumPolicy.ATTRIBUTE and definition.maximum_attribute_id == attribute_id:
			meter.set_maximum(_attributes.get_value(attribute_id), definition.maximum_change_policy)

# ====== HELPERS ========
func _emit_meter_event(event_id: StringName, meter_id: StringName, payload: Dictionary, execution_context: GameExecutionContext) -> void:
	var context: GameObjectContext = get_context()
	if context != null: publish_local_event(GameLocalEvent.new(event_id, context.get_object_handle(), execution_context, payload.merged({"meter_id": meter_id})))

# ====== PUBLIC ========
## Returns whether this component owns [param meter_id].
func has_meter(meter_id: StringName) -> bool: return _values.has(meter_id)
## Returns the current amount, or [param fallback] when the meter is absent.
func get_current(meter_id: StringName, fallback: float = 0.0) -> float: return (_values[meter_id] as GameMeterValue).get_current() if _values.has(meter_id) else fallback
## Returns the resolved maximum, or [param fallback] when the meter is absent.
func get_maximum(meter_id: StringName, fallback: float = 0.0) -> float: return (_values[meter_id] as GameMeterValue).get_maximum() if _values.has(meter_id) else fallback
## Applies [param delta] to a meter and publishes change and threshold events.
func modify_current(meter_id: StringName, delta: float, execution_context: GameExecutionContext, reason: StringName = &"meter_modified") -> GameCommandResult:
	if not _values.has(meter_id): return GameCommandResult.rejected_permanent(&"unknown_meter", "Unknown meter '%s'." % meter_id)
	var change: Dictionary = (_values[meter_id] as GameMeterValue).set_current(get_current(meter_id) + delta)
	_emit_meter_event(&"meter_changed", meter_id, change.merged({"reason": reason}), execution_context)
	if change.depleted_crossed: _emit_meter_event(&"meter_depleted", meter_id, change, execution_context)
	if change.filled_crossed: _emit_meter_event(&"meter_filled", meter_id, change, execution_context)
	return GameCommandResult.success_changed(reason, change)
## Returns diagnostic state for every meter, keyed by meter ID.
func get_debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for meter_id: StringName in _values.keys(): snapshot[meter_id] = (_values[meter_id] as GameMeterValue).get_debug_snapshot()
	return snapshot
