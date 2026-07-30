extends GameFeature
class_name GameTestCounterFeature

# ======= CONSTS =========
const COMMAND_INCREMENT: StringName = &"test.counter.increment"
const QUERY_VALUE: StringName = &"test.counter.value"
const EVENT_CHANGED: StringName = &"test.counter.changed"

# ======== EXPORT =========
@export var initial_value: int = 0

# ======== PRIVATE VAR ======
var _value: int = 0

# ======= OVERRIDE =======
func _init() -> void:
	if feature_id.is_empty():
		feature_id = &"test.counter"
	if provided_capabilities.is_empty():
		var spec := GameCapabilitySpec.new()
		spec.capability_id = GameCapabilityIds.TEST_COUNTER
		spec.cardinality = GameCapabilityCardinality.Type.EXCLUSIVE
		provided_capabilities = [spec]

# ====== PUBLIC ========
func on_game_initialize() -> GameCommandResult:
	_value = initial_value
	return GameCommandResult.success_changed(&"counter_initialized", _value)

func can_handle_command(command_type_id: StringName) -> bool:
	return command_type_id == COMMAND_INCREMENT

func handle_command(command: GameCommand) -> GameCommandResult:
	var amount: int = int(command.get_payload()) if command.get_payload() != null else 1
	_value += amount
	var context: GameObjectContext = get_context()
	var event := GameLocalEvent.new(
		EVENT_CHANGED,
		context.get_object_handle(),
		command.get_execution_context(),
		{"value": _value, "delta": amount}
	)
	publish_local_event(event)
	return GameCommandResult.success_changed(&"counter_incremented", _value)

func can_handle_query(query_type_id: StringName) -> bool:
	return query_type_id == QUERY_VALUE

func handle_query(_query: GameQuery) -> GameQueryResult:
	return GameQueryResult.found_value(_value)

func get_value() -> int:
	return _value
