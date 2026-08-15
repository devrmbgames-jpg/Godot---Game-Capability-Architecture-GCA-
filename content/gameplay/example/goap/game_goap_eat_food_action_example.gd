extends GameGOAPTimedActionExample
class_name GameGOAPEatFoodActionExample

# ======= OVERRIDE =======
func _init() -> void:
	preconditions = {"food_cooked": true, "hungry": true}
	effects = {"hungry": false}
	cost = 1
