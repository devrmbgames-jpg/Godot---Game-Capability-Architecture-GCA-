extends GameFeature
class_name GameTestThresholdFeature

# ======= CONSTS =========
const EVENT_REACHED: StringName = &"test.threshold.reached"

# ======== EXPORT =========
@export var threshold: int = 3

# ======== PRIVATE VAR ======
var _counter: GameTestCounterFeature = null
var _reached_count: int = 0

# ======= OVERRIDE =======
func _init() -> void:
    if feature_id.is_empty():
        feature_id = &"test.threshold"
    if required_dependencies.is_empty():
        var dependency := GameCapabilityDependency.new()
        dependency.capability_id = GameCapabilityIds.TEST_COUNTER
        dependency.required = true
        dependency.expected_cardinality = GameCapabilityCardinality.Type.EXCLUSIVE
        dependency.expected_contract = load("res://content/core/testing/features/game_test_counter_feature.gd")
        required_dependencies = [dependency]

# ====== PUBLIC ========
func on_game_initialize() -> GameCommandResult:
    _counter = get_dependency(GameCapabilityIds.TEST_COUNTER) as GameTestCounterFeature
    if _counter == null:
        return GameCommandResult.configuration_error(&"counter_dependency_invalid", "Threshold feature did not receive a counter dependency.")
    return GameCommandResult.success_changed(&"threshold_initialized")

func on_local_event(event: GameLocalEvent) -> void:
    if event.get_event_type_id() != GameTestCounterFeature.EVENT_CHANGED:
        return
    var payload: Dictionary = event.get_payload() as Dictionary
    if int(payload.get("value", 0)) < threshold:
        return
    _reached_count += 1
    var context: GameObjectContext = get_context()
    publish_local_event(GameLocalEvent.new(
        EVENT_REACHED,
        context.get_object_handle(),
        event.get_execution_context(),
        {"threshold": threshold, "value": payload.get("value")}
    ))

func get_cached_counter() -> GameTestCounterFeature:
    return _counter

func get_reached_count() -> int:
    return _reached_count
