extends GameGOAPTimedActionExample
class_name GameGOAPTakeFoodActionExample

# ======= OVERRIDE =======
func _init() -> void:
	preconditions = {"food_found": true, "has_food": false}
	effects = {"has_food": true}
	cost = 1
