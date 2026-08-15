extends Node
## Exposes a restricted GCA query and command surface to Dialogue Manager.
##
## Dialogue content addresses participants by stable ID and receives primitive values or
## serialized command results. Internal component nodes are never exposed to dialogue code.
class_name GameDialogueAdapter

# ======== EXPORT =========
@export var object_resolver: GameObjectResolver = null
@export var effect_definitions: Dictionary = {}
@export var ability_definitions: Dictionary = {}

# ====== HELPERS ========
func _context(stable_id: StringName) -> GameObjectContext:
	var handle: GameObjectHandle = object_resolver.resolve(stable_id) if object_resolver != null else null
	return handle.get_context() if handle != null and handle.is_resolved() else null

# ====== PUBLIC ========
## Returns whether the resolved participant identified by [param stable_id] has [param tag_id] or a child tag.
func has_tag(stable_id: StringName, tag_id: StringName) -> bool:
	var context: GameObjectContext = _context(stable_id)
	return context != null and context.has_tag_or_child(tag_id)

## Returns the current meter value for a resolved participant, or [param fallback].
func get_meter(stable_id: StringName, meter_id: StringName, fallback: float = 0.0) -> float:
	var context: GameObjectContext = _context(stable_id)
	var meters: GameMeters = context.get_capability(GameCapabilityIds.METERS_QUERY) as GameMeters if context != null else null
	return meters.get_current(meter_id, fallback) if meters != null else fallback

## Changes a participant meter through the GCA meter port and returns a serialized [GameCommandResult].
func modify_meter(stable_id: StringName, meter_id: StringName, delta: float) -> Dictionary:
	var context: GameObjectContext = _context(stable_id)
	if context == null:
		return GameCommandResult.invalid_target("Dialogue participant unresolved.").to_dictionary()
	var meters: GameMeters = context.get_capability(GameCapabilityIds.METERS_MODIFY) as GameMeters
	if meters == null:
		return GameCommandResult.missing_capability(GameCapabilityIds.METERS_MODIFY).to_dictionary()
	var execution_context: GameExecutionContext = context.create_root_execution_context(&"dialogue.command", "Dialogue command")
	return meters.modify_current(meter_id, delta, execution_context, &"dialogue_meter_modified").to_dictionary()

## Grants the registered ability definition to a resolved participant and returns a serialized result.
func grant_ability(stable_id: StringName, ability_id: StringName) -> Dictionary:
	var context: GameObjectContext = _context(stable_id)
	var definition: GameAbilityDefinition = ability_definitions.get(ability_id) as GameAbilityDefinition
	if context == null:
		return GameCommandResult.invalid_target("Dialogue participant unresolved.").to_dictionary()
	var abilities: GameAbilities = context.get_capability(GameCapabilityIds.ABILITIES_GRANT) as GameAbilities
	if abilities == null:
		return GameCommandResult.missing_capability(GameCapabilityIds.ABILITIES_GRANT).to_dictionary()
	if definition == null:
		return GameCommandResult.configuration_error(&"unknown_ability_definition", "Definition is not registered.").to_dictionary()
	return abilities.grant_ability(definition, context.get_object_handle(), &"dialogue.reward").to_dictionary()
