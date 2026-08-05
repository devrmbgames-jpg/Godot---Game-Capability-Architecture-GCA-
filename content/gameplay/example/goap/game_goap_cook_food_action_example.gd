extends GameGOAPTimedActionExample
class_name GameGOAPCookFoodActionExample

# ======= OVERRIDE =======
func _init() -> void:
	preconditions = {"has_food": true, "food_cooked": false}
	effects = {"food_cooked": true}
	cost = 2
