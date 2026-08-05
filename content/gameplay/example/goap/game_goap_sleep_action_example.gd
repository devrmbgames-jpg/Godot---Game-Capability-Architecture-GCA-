extends GameGOAPTimedActionExample
class_name GameGOAPSleepActionExample

# ======= OVERRIDE =======
func _init() -> void:
	preconditions = {"hungry": false, "tired": true}
	effects = {"tired": false}
	cost = 1
