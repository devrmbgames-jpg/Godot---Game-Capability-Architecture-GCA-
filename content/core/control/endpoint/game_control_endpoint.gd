@tool
extends GameFeature
## Endpoint that validates and routes normalized control intents.
##
## Verifies channel ownership and gameplay blocking tags, then delegates movement,
## ability, or interaction work to optional capability providers.
class_name GameControlEndpoint

## Emitted after an intent is successfully routed.
signal intent_accepted(intent: GameControlIntent, result: GameCommandResult)
## Emitted when validation or delegated execution rejects an intent.
signal intent_rejected(intent: GameControlIntent, result: GameCommandResult)

# ======== PRIVATE VAR ======
var _arbiter: GameControlArbiter = null
var _motor: GameMovementMotor = null
var _abilities: GameAbilities = null
var _interaction_source: GameInteractionSource = null
var _continuous_intents: Dictionary = {}

# ======= OVERRIDE =======
## Configures endpoint capabilities and local executor dependencies.
func _init() -> void:
	feature_id = &"object.control_endpoint"
	if provided_capabilities.is_empty():
		for capability_id: StringName in [GameCapabilityIds.CONTROL_ENDPOINT, GameCapabilityIds.CONTROL_INTENT_RECEIVER, GameCapabilityIds.CONTROL_QUERY]:
			var spec := GameCapabilitySpec.new()
			spec.capability_id = capability_id
			provided_capabilities.append(spec)
	if required_dependencies.is_empty():
		var arbiter_dependency := GameCapabilityDependency.new()
		arbiter_dependency.capability_id = GameCapabilityIds.CONTROL_ARBITER
		required_dependencies.append(arbiter_dependency)
	if optional_dependencies.is_empty():
		for capability_id: StringName in [GameCapabilityIds.MOVEMENT_MOTOR, GameCapabilityIds.ABILITIES_ACTIVATE, GameCapabilityIds.INTERACTION_SOURCE]:
			var dependency := GameCapabilityDependency.new()
			dependency.capability_id = capability_id
			dependency.required = false
			optional_dependencies.append(dependency)

## Resolves the arbiter and optional executor capabilities.
func on_game_initialize() -> GameCommandResult:
	_arbiter = get_dependency(GameCapabilityIds.CONTROL_ARBITER) as GameControlArbiter
	_motor = get_dependency(GameCapabilityIds.MOVEMENT_MOTOR) as GameMovementMotor
	_abilities = get_dependency(GameCapabilityIds.ABILITIES_ACTIVATE) as GameAbilities
	_interaction_source = get_dependency(GameCapabilityIds.INTERACTION_SOURCE) as GameInteractionSource
	if _arbiter == null: return GameCommandResult.configuration_error(&"missing_control_arbiter", "Control endpoint requires a control arbiter.")
	return GameCommandResult.success_changed(&"control_endpoint_initialized")

## Clears retained continuous intents and dependency references.
func on_game_shutdown() -> void:
	_continuous_intents.clear(); _arbiter = null; _motor = null; _abilities = null; _interaction_source = null

# ====== HELPERS ========
func _is_blocked(channel_id: StringName) -> bool:
	var context: GameObjectContext = get_context()
	return context.has_tag_or_child(&"control.block.all") or context.has_tag_or_child(StringName("control.block.%s" % channel_id)) or context.has_tag_or_child(&"state.dead")

func _route_movement(intent: GameControlIntent) -> GameCommandResult:
	if _motor == null: return GameCommandResult.missing_capability(GameCapabilityIds.MOVEMENT_MOTOR)
	var payload: Dictionary = intent.get_payload()
	var request_type: int = GameMovementRequest.Type.SET_DESIRED_MOVEMENT
	if intent.get_intent_type() == &"movement.stop": request_type = GameMovementRequest.Type.STOP
	elif intent.get_intent_type() == &"movement.move_to": request_type = GameMovementRequest.Type.MOVE_TO_POINT
	var request := GameMovementRequest.new(request_type, intent.get_execution_context())
	request.set_direction(payload.get("direction", Vector3.ZERO))
	request.set_magnitude(float(payload.get("magnitude", 0.0)))
	request.set_target_point(payload.get("target_point", Vector3.ZERO))
	request.set_tolerance(float(payload.get("tolerance", 0.1)))
	request.set_payload(payload)
	return _motor.apply_movement_request(request)

func _route_ability(intent: GameControlIntent) -> GameCommandResult:
	if _abilities == null: return GameCommandResult.missing_capability(GameCapabilityIds.ABILITIES_ACTIVATE)
	var payload: Dictionary = intent.get_payload()
	var request := GameAbilityActivationRequest.new(payload.get("ability_id", &""), get_owner_handle(), intent.get_execution_context(), get_owner_handle())
	request.set_grant_handle_id(int(payload.get("grant_handle_id", 0)))
	request.set_targets(payload.get("targets", []))
	request.set_target_point(payload.get("target_point", Vector3.ZERO))
	request.set_target_direction(payload.get("target_direction", Vector3.ZERO))
	request.set_activation_payload(payload.get("activation_payload", {}))
	return _abilities.activate(request)

func _route_interaction(intent: GameControlIntent) -> GameCommandResult:
	if _interaction_source == null: return GameCommandResult.missing_capability(GameCapabilityIds.INTERACTION_SOURCE)
	return _interaction_source.handle_interaction_intent(intent)

# ====== PUBLIC ========
## Returns the controlled object's handle from the local context.
func get_owner_handle() -> GameObjectHandle:
	var context: GameObjectContext = get_context()
	return context.get_object_handle() if context != null else null

## Validates ownership and blocking state, then routes one control intent.
func receive_intent(intent: GameControlIntent) -> GameCommandResult:
	if intent == null or not intent.is_valid(): return GameCommandResult.configuration_error(&"invalid_control_intent", "Control intent is invalid.")
	if not _arbiter.owns_channel(intent.get_source_id(), intent.get_channel_id()):
		var ownership_result := GameCommandResult.rejected_temporary(&"control_not_owned", "Source does not own the requested control channel.")
		intent_rejected.emit(intent, ownership_result)
		return ownership_result
	if _is_blocked(intent.get_channel_id()):
		var blocked_result := GameCommandResult.new(GameCommandResult.Status.BLOCKED_BY_TAG, &"control_blocked", "Control channel is blocked by gameplay state.")
		intent_rejected.emit(intent, blocked_result)
		return blocked_result
	var result: GameCommandResult
	match intent.get_channel_id():
		GameControlChannels.MOVEMENT, GameControlChannels.LOOK:
			result = _route_movement(intent)
		GameControlChannels.ABILITIES:
			result = _route_ability(intent)
		GameControlChannels.INTERACTION:
			result = _route_interaction(intent)
		_:
			result = GameCommandResult.rejected_permanent(&"unsupported_control_channel", "Endpoint does not route this channel yet.")
	if result.is_success():
		if intent.is_continuous(): _continuous_intents[intent.get_channel_id()] = intent
		intent_accepted.emit(intent, result)
	else: intent_rejected.emit(intent, result)
	return result

## Removes retained continuous state for [param channel_id].
## Movement clearing also sends an explicit stop request to the motor.
func clear_continuous_intent(channel_id: StringName) -> void:
	_continuous_intents.erase(channel_id)
	if channel_id == GameControlChannels.MOVEMENT and _motor != null:
		var context: GameExecutionContext = get_context().create_root_execution_context(&"control.clear", "Continuous movement cleared")
		_motor.apply_movement_request(GameMovementRequest.new(GameMovementRequest.Type.STOP, context))

## Returns retained intents and availability of optional executor features.
func get_debug_snapshot() -> Dictionary:
	var intents: Dictionary = {}
	for channel_id: StringName in _continuous_intents.keys(): intents[channel_id] = (_continuous_intents[channel_id] as GameControlIntent).to_dictionary()
	return {"continuous_intents": intents, "has_motor": _motor != null, "has_abilities": _abilities != null, "has_interaction": _interaction_source != null}
