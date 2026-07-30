extends GameFeature
class_name GameTestEventRecorderFeature

# ======== PRIVATE VAR ======
var _event_types: Array[StringName] = []
var _event_sequences: Array[int] = []

# ======= OVERRIDE =======
func _init() -> void:
    if feature_id.is_empty():
        feature_id = &"test.event_recorder"

# ====== PUBLIC ========
func on_local_event(event: GameLocalEvent) -> void:
    _event_types.append(event.get_event_type_id())
    _event_sequences.append(event.get_sequence())

func get_event_types() -> Array[StringName]:
    return _event_types.duplicate()

func get_event_sequences() -> Array[int]:
    return _event_sequences.duplicate()
