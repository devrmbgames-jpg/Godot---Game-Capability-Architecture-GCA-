extends GameFeature
class_name GameTestEventRemovalFeature

# ======== PRIVATE VAR ======
var _removal_requested: bool = false

# ======= OVERRIDE =======
func _init() -> void:
    if feature_id.is_empty():
        feature_id = &"test.event_removal"

# ====== PUBLIC ========
func on_local_event(event: GameLocalEvent) -> void:
    if event.get_event_type_id() == GameTestCounterFeature.EVENT_CHANGED and not _removal_requested:
        _removal_requested = true
        request_runtime_removal()

func was_removal_requested() -> bool:
    return _removal_requested
