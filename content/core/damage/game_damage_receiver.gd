@tool
extends GameFeature
## Capability provider that applies damage to a configured meter.
##
## Validates damage requests, checks blocking tags, applies optional flat defense,
## modifies the target meter, and publishes a local damage event.
class_name GameDamageReceiver

# ======== EXPORT =========
@export var target_meter_id: StringName = &"health"
@export var flat_defense_attribute_id: StringName = &""
@export var blocked_damage_tags: Array[StringName] = []

# ======== PRIVATE VAR ======
var _meters: GameMeters = null
var _attributes: GameAttributes = null

# ======= OVERRIDE =======
## Configures the damage capability and required meter dependency.
func _init() -> void:
	feature_id = &"object.damage_receiver"
	if provided_capabilities.is_empty():
		var spec := GameCapabilitySpec.new(); spec.capability_id = GameCapabilityIds.DAMAGE_RECEIVER; spec.cardinality = GameCapabilityCardinality.Type.EXCLUSIVE; provided_capabilities.append(spec)
	if required_dependencies.is_empty():
		var meter_dependency := GameCapabilityDependency.new(); meter_dependency.capability_id = GameCapabilityIds.METERS_MODIFY; meter_dependency.required = true; required_dependencies.append(meter_dependency)
	if optional_dependencies.is_empty():
		var attribute_dependency := GameCapabilityDependency.new(); attribute_dependency.capability_id = GameCapabilityIds.ATTRIBUTES_QUERY; attribute_dependency.required = false; optional_dependencies.append(attribute_dependency)

## Returns editor warnings for missing meter configuration.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = super()
	if target_meter_id.is_empty(): warnings.append("GameDamageReceiver requires target_meter_id.")
	return warnings

## Resolves meter and optional attribute dependencies before activation.
func on_game_initialize() -> GameCommandResult:
	_meters = get_dependency(GameCapabilityIds.METERS_MODIFY) as GameMeters
	_attributes = get_dependency(GameCapabilityIds.ATTRIBUTES_QUERY) as GameAttributes
	if _meters == null or not _meters.has_meter(target_meter_id): return GameCommandResult.configuration_error(&"missing_damage_meter", "Damage receiver target meter is unavailable.")
	return GameCommandResult.success_changed(&"damage_receiver_initialized")

## Returns whether this feature accepts the damage command type.
func can_handle_command(command_type_id: StringName) -> bool:
	return command_type_id == &"damage.apply"

## Extracts and validates [GameDamageRequest] payloads before applying damage.
func handle_command(command: GameCommand) -> GameCommandResult:
	var request: GameDamageRequest = command.get_payload() as GameDamageRequest
	if request == null or not request.is_valid(): return GameCommandResult.rejected_permanent(&"invalid_damage_request", "Damage request is invalid.")
	return apply_damage(request)

# ====== PUBLIC ========
## Applies one validated damage request to the configured meter.
## Returns a structured result containing final damage and meter change data.
func apply_damage(request: GameDamageRequest) -> GameCommandResult:
	var context: GameObjectContext = get_context()
	for blocked_tag: StringName in blocked_damage_tags:
		if request.get_damage_type_tags().has(blocked_tag) or (context != null and context.has_tag_or_child(blocked_tag)):
			return GameCommandResult.new(GameCommandResult.Status.BLOCKED_BY_TAG, &"damage_blocked", "Damage was blocked by tag.")
	var defense: float = 0.0
	if _attributes != null and not flat_defense_attribute_id.is_empty(): defense = maxf(0.0, _attributes.get_value(flat_defense_attribute_id))
	var final_damage: float = maxf(0.0, request.get_base_amount() - defense)
	var result: GameCommandResult = _meters.modify_current(target_meter_id, -final_damage, request.get_execution_context(), &"damage_applied")
	if not result.is_success(): return result
	if context != null:
		publish_local_event(GameLocalEvent.new(&"damage_applied", context.get_object_handle(), request.get_execution_context(), {&"base_damage": request.get_base_amount(), &"mitigated": request.get_base_amount() - final_damage, &"final_damage": final_damage, &"meter_id": target_meter_id}))
	return GameCommandResult.success_changed(&"damage_applied", {&"final_damage": final_damage, &"meter_change": result.get_payload()})
