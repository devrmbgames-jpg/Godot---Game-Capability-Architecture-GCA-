extends GameFeature
class_name GameTestChainFeature

# ======= CONSTS =========
const COMMAND_START: StringName = &"test.chain.start"
const OPERATION_STEP: StringName = &"test.chain.step"

# ======== PRIVATE VAR ======
var _executed_contexts: Array[Dictionary] = []

# ======= OVERRIDE =======
func _init() -> void:
	if feature_id.is_empty():
		feature_id = &"test.chain"
	if provided_capabilities.is_empty():
		var spec := GameCapabilitySpec.new()
		spec.capability_id = GameCapabilityIds.TEST_CHAIN
		spec.cardinality = GameCapabilityCardinality.Type.EXCLUSIVE
		provided_capabilities = [spec]

# ====== HELPERS ========
func _execute_chain_step(context: GameExecutionContext, remaining: int) -> GameCommandResult:
	_executed_contexts.append(context.to_dictionary())
	if remaining > 0:
		var object_context: GameObjectContext = get_context()
		var child_context: GameExecutionContext = object_context.create_child_execution_context(context, OPERATION_STEP, "chain_step_%s" % remaining)
		var child := GameCallbackOperation.new(
			OPERATION_STEP,
			child_context,
			_execute_chain_step.bind(remaining - 1),
			&"test.chain",
			object_context.get_object_handle(),
			StringName("step.%s" % remaining),
            "Test chain step"
		)
		var enqueue_result: GameCommandResult = object_context.enqueue_operation(child)
		if not enqueue_result.is_success():
			return enqueue_result
	return GameCommandResult.success_changed(&"chain_step_executed", remaining)

# ====== PUBLIC ========
func can_handle_command(command_type_id: StringName) -> bool:
	return command_type_id == COMMAND_START

func handle_command(command: GameCommand) -> GameCommandResult:
	var steps: int = maxi(1, int(command.get_payload()))
	var root_context: GameExecutionContext = command.get_execution_context()
	var operation := GameCallbackOperation.new(
		OPERATION_STEP,
		root_context,
		_execute_chain_step.bind(steps - 1),
		&"test.chain",
		get_context().get_object_handle(),
		&"step.root",
        "Test chain root"
	)
	return get_context().enqueue_operation(operation)

func get_executed_contexts() -> Array[Dictionary]:
	return _executed_contexts.duplicate(true)
