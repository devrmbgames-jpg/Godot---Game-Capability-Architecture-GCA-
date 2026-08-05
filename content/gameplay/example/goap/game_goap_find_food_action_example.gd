extends GameGOAPTimedActionExample
class_name GameGOAPFindFoodActionExample

# ======= OVERRIDE =======
func _init() -> void:
	preconditions = {"food_found": false}
	effects = {"food_found": true}
	cost = 1
