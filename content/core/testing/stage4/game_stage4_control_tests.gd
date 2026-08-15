extends RefCounted
## Isolated contract tests for Stage 4 control ownership, slots, and semantic interaction data.
class_name GameStage4ControlTests

# ====== PUBLIC ========
## Verifies temporary high-priority ownership preemption and automatic previous-owner restoration.
static func test_arbiter_preemption_and_restore() -> void:
	var arbiter := GameControlArbiter.new()
	var player := GameControlSource.new()
	player.source_id = &"test.player"
	player.priority = 0
	var scripted := GameControlSource.new()
	scripted.source_id = &"test.scripted"
	scripted.priority = 100
	assert(arbiter.register_source(player).is_success())
	assert(arbiter.register_source(scripted).is_success())
	assert(arbiter.request_ownership(player.source_id, GameControlChannels.MOVEMENT, player.priority).is_success())
	assert(arbiter.owns_channel(player.source_id, GameControlChannels.MOVEMENT))
	assert(arbiter.request_ownership(scripted.source_id, GameControlChannels.MOVEMENT, scripted.priority, true).is_success())
	assert(arbiter.owns_channel(scripted.source_id, GameControlChannels.MOVEMENT))
	assert(arbiter.release_ownership(scripted.source_id, GameControlChannels.MOVEMENT).is_success())
	assert(arbiter.owns_channel(player.source_id, GameControlChannels.MOVEMENT))
	player.free()
	scripted.free()
	arbiter.free()

## Verifies that a lower-priority source cannot preempt an occupied channel.
static func test_lower_priority_cannot_preempt() -> void:
	var arbiter := GameControlArbiter.new()
	var high := GameControlSource.new()
	high.source_id = &"test.high"
	high.priority = 10
	var low := GameControlSource.new()
	low.source_id = &"test.low"
	low.priority = 1
	arbiter.register_source(high)
	arbiter.register_source(low)
	arbiter.request_ownership(high.source_id, GameControlChannels.ABILITIES, high.priority)
	var result: GameCommandResult = arbiter.request_ownership(low.source_id, GameControlChannels.ABILITIES, low.priority)
	assert(not result.is_success())
	assert(result.get_reason_code() == &"channel_occupied")
	high.free()
	low.free()
	arbiter.free()

## Verifies normalized control intent validation and continuous consumption policy.
static func test_control_intent_validation() -> void:
	var context := GameExecutionContext.new()
	var intent := GameControlIntent.new(&"movement.desired", &"test.source", null, GameControlChannels.MOVEMENT, context, {"direction": Vector3.FORWARD}, GameControlIntent.ConsumePolicy.CONTINUOUS)
	assert(intent.is_valid())
	assert(intent.is_continuous())

## Verifies player input bindings target logical slots instead of concrete ability IDs.
static func test_ability_input_binding_contract() -> void:
	var binding := GameAbilityInputBinding.new()
	binding.input_action = &"interact"
	binding.slot_id = &"slot.interaction"
	assert(binding.is_valid())

## Verifies runtime slot bindings preserve source, priority, and grant identity.
static func test_ability_slot_binding_contract() -> void:
	var binding := GameAbilitySlotBinding.new(
		7,
		&"slot.primary",
		42,
		&"item.sword.instance_1",
		100
	)
	assert(binding.is_valid())
	assert(binding.get_handle_id() == 7)
	assert(binding.get_grant_handle_id() == 42)
	assert(binding.get_source_id() == &"item.sword.instance_1")
	assert(binding.get_priority() == 100)

## Verifies semantic interaction request supports default and explicit-intent activation.
static func test_interaction_request_contract() -> void:
	var source := GameObjectHandle.new(&"test.source", 1)
	var target := GameObjectHandle.new(&"test.target", 1)
	var context := GameExecutionContext.new()
	var default_request := GameInteractionRequest.new(source, target, &"", context)
	assert(default_request.is_valid())
	assert(default_request.get_intent_id().is_empty())
	var open_request := GameInteractionRequest.new(source, target, &"open", context)
	assert(open_request.is_valid())
	assert(open_request.get_intent_id() == &"open")

## Verifies target-local reactions separate semantic intent from owned ability implementation.
static func test_interaction_reaction_contract() -> void:
	var reaction := GameInteractionReaction.new()
	reaction.offer_id = &"door.open"
	reaction.intent_id = &"open"
	reaction.verb_id = &"verb.open"
	reaction.ability_id = &"ability.door.open"
	reaction.priority = 50
	reaction.default_candidate = true
	assert(reaction.is_valid())

	var handle := GameObjectHandle.new(&"test.target", 1)
	var offer: GameInteractionOffer = reaction.build_offer(handle)
	assert(offer != null)
	assert(offer.is_valid())
	assert(offer.get_intent_id() == &"open")
	assert(not offer.to_dictionary().has("ability_id"))
	assert(not offer.to_dictionary().has("command_id"))
