@tool
extends GameControlSource
class_name GameMockAIControlSource

# ======= OVERRIDE =======
func _init() -> void:
	if source_id.is_empty(): source_id = &"control.mock_ai"
	priority = 10
	if requested_channels.is_empty(): requested_channels = [GameControlChannels.MOVEMENT, GameControlChannels.ABILITIES, GameControlChannels.INTERACTION]

# ====== PUBLIC ========
func move(direction: Vector3, magnitude: float, execution_context: GameExecutionContext) -> GameCommandResult:
	return submit_intent(&"movement.desired", GameControlChannels.MOVEMENT, execution_context, {"direction": direction.normalized(), "magnitude": clampf(magnitude, 0.0, 1.0)}, true)

func stop(execution_context: GameExecutionContext) -> GameCommandResult:
	return submit_intent(&"movement.stop", GameControlChannels.MOVEMENT, execution_context)

func use_ability(ability_id: StringName, target_handles: Array[GameObjectHandle], execution_context: GameExecutionContext) -> GameCommandResult:
	return submit_intent(&"ability.activate", GameControlChannels.ABILITIES, execution_context, {"ability_id": ability_id, "targets": target_handles})

func focus_interaction(target_handle: GameObjectHandle, execution_context: GameExecutionContext) -> GameCommandResult:
	return submit_intent(&"interaction.focus", GameControlChannels.INTERACTION, execution_context, {"target_handle": target_handle})
