extends GoapAction
class_name GameGOAPTimedActionExample

# ======== EXPORT =========
@export_range(0.01, 10.0, 0.01) var action_duration: float = 0.08

# ======== PRIVATE VAR ======
var _elapsed: float = 0.0

# ======= OVERRIDE =======
func enter() -> void:
	_elapsed = 0.0

func perform(delta) -> bool:
	_elapsed += maxf(0.0, float(delta))
	return _elapsed >= action_duration

func get_cost(_blackboard) -> int:
	return cost
