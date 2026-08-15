extends GoapGoal
class_name GameGOAPSurvivalGoalExample

# ======= OVERRIDE =======
func _init() -> void:
	priority = 100
	cost = 0
	desired_state = {"hungry": false, "tired": false}

func is_valid() -> bool:
	if _world_state == null:
		return true
	return bool(_world_state.get_state("hungry", true)) or bool(_world_state.get_state("tired", true))
