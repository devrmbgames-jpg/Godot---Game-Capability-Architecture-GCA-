extends Node
## Translates GCA state and control requests to a GOAP plugin-facing boundary.
##
## The adapter keeps GOAP facts outside core gameplay contracts and routes agent actions
## through the standard control pipeline instead of mutating gameplay state directly.
class_name GameGOAPAdapter

# ======== EXPORT =========
@export var object_kernel: GameObjectKernel = null
@export var goap_world_state: Node = null
@export var control_source: GameControlSource = null
@export var fact_mappings: Dictionary = {}

# ======== PRIVATE VAR ======
var _fact_sources: Dictionary = {}

# ====== PUBLIC ========
## Rebuilds configured GOAP facts from GCA tags and meters.
##
## The target plugin node must expose a [code]set_state(name, value)[/code] method.
## Missing capabilities use each mapping's configured fallback value.
func refresh_projection() -> void:
	if object_kernel == null or goap_world_state == null or not goap_world_state.has_method("set_state"):
		return
	var context: GameObjectContext = object_kernel.get_object_context()
	if context == null:
		return
	var fact_ids: Array = fact_mappings.keys()
	fact_ids.sort()
	for fact_id: StringName in fact_ids:
		var mapping: Dictionary = fact_mappings[fact_id]
		var value: Variant = mapping.get("fallback", false)
		match StringName(mapping.get("type", &"")):
			&"tag":
				value = context.has_tag_or_child(mapping.get("tag_id", &""))
			&"meter":
				var meters: GameMeters = context.get_capability(GameCapabilityIds.METERS_QUERY) as GameMeters
				if meters != null:
					value = meters.get_current(mapping.get("meter_id", &""), float(value))
		goap_world_state.call("set_state", String(fact_id), value)
		_fact_sources[fact_id] = {"value": value, "source": mapping.get("type", &"")}

## Requests continuous movement toward [param point] through the configured control source.
func request_move_to(point: Vector3, execution_context: GameExecutionContext) -> GameCommandResult:
	if control_source == null:
		return GameCommandResult.invalid_target("GOAP control source is missing.")
	return control_source.submit_intent(&"movement.move_to", GameControlChannels.MOVEMENT, execution_context, {"target_point": point, "tolerance": 0.25}, true)

## Requests activation of [param ability_id] through the standard ability control channel.
func request_ability(ability_id: StringName, execution_context: GameExecutionContext, targets: Array[GameObjectHandle] = []) -> GameCommandResult:
	if control_source == null:
		return GameCommandResult.invalid_target("GOAP control source is missing.")
	return control_source.submit_intent(&"ability.activate", GameControlChannels.ABILITIES, execution_context, {"ability_id": ability_id, "targets": targets})

## Returns the latest projected facts and their configured source types.
func get_debug_snapshot() -> Dictionary:
	return _fact_sources.duplicate(true)
