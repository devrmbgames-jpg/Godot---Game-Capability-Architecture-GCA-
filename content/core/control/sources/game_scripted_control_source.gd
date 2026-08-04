@tool
extends GameControlSource
class_name GameScriptedControlSource

# ======= OVERRIDE =======
func _init() -> void:
	if source_id.is_empty(): source_id = &"control.scripted"
	priority = 100
	if requested_channels.is_empty(): requested_channels = [GameControlChannels.MOVEMENT, GameControlChannels.LOOK, GameControlChannels.ABILITIES, GameControlChannels.INTERACTION]

# ====== PUBLIC ========
func acquire_temporary(channels: Array[StringName]) -> Dictionary:
	var results: Dictionary = {}
	if _arbiter == null: return results
	for channel_id: StringName in channels:
		results[channel_id] = _arbiter.request_ownership(source_id, channel_id, priority, true)
	return results

func release_channels(channels: Array[StringName]) -> void:
	if _arbiter == null: return
	for channel_id: StringName in channels: _arbiter.release_ownership(source_id, channel_id)

func move_to(point: Vector3, tolerance: float, execution_context: GameExecutionContext) -> GameCommandResult:
	return submit_intent(&"movement.move_to", GameControlChannels.MOVEMENT, execution_context, {"target_point": point, "tolerance": tolerance}, true)

func activate_ability(ability_id: StringName, execution_context: GameExecutionContext, payload: Dictionary = {}) -> GameCommandResult:
	var intent_payload: Dictionary = payload.duplicate(true)
	intent_payload["ability_id"] = ability_id
	return submit_intent(&"ability.activate", GameControlChannels.ABILITIES, execution_context, intent_payload)

func execute_interaction(execution_context: GameExecutionContext) -> GameCommandResult:
	return submit_intent(&"interaction.execute", GameControlChannels.INTERACTION, execution_context)
