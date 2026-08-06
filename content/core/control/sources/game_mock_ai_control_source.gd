@tool
extends GameControlSource
## Minimal AI control source used to validate the shared control pipeline.
##
## Converts explicit AI decisions into the same movement, ability, and interaction
## intents used by player and scripted sources.
class_name GameMockAIControlSource

# ======= OVERRIDE =======
## Assigns mock-AI identity, priority, and default requested channels.
func _init() -> void:
	if source_id.is_empty(): source_id = &"control.mock_ai"
	priority = 10
	if requested_channels.is_empty(): requested_channels = [GameControlChannels.MOVEMENT, GameControlChannels.ABILITIES, GameControlChannels.INTERACTION]

# ====== PUBLIC ========
## Sends a normalized continuous movement intent.
func move(direction: Vector3, magnitude: float, execution_context: GameExecutionContext) -> GameCommandResult:
	return submit_intent(&"movement.desired", GameControlChannels.MOVEMENT, execution_context, {"direction": direction.normalized(), "magnitude": clampf(magnitude, 0.0, 1.0)}, true)

## Sends a one-shot movement stop intent.
func stop(execution_context: GameExecutionContext) -> GameCommandResult:
	return submit_intent(&"movement.stop", GameControlChannels.MOVEMENT, execution_context)

## Sends an ability activation intent with explicit target handles.
func use_ability(ability_id: StringName, target_handles: Array[GameObjectHandle], execution_context: GameExecutionContext) -> GameCommandResult:
	return submit_intent(&"ability.activate", GameControlChannels.ABILITIES, execution_context, {"ability_id": ability_id, "targets": target_handles})

## Sends an interaction focus intent for [param target_handle].
func focus_interaction(target_handle: GameObjectHandle, execution_context: GameExecutionContext) -> GameCommandResult:
	return submit_intent(&"interaction.focus", GameControlChannels.INTERACTION, execution_context, {"target_handle": target_handle})
