extends RefCounted
class_name GameControlChannels

# ======= CONSTS =========
const MOVEMENT: StringName = &"movement"
const LOOK: StringName = &"look"
const ABILITIES: StringName = &"abilities"
const INTERACTION: StringName = &"interaction"
const CAMERA: StringName = &"camera"
const TARGETING: StringName = &"targeting"
const UI_NAVIGATION: StringName = &"ui_navigation"

const ALL: Array[StringName] = [
	MOVEMENT,
	LOOK,
	ABILITIES,
	INTERACTION,
	CAMERA,
	TARGETING,
	UI_NAVIGATION,
]

# ====== PUBLIC ========
static func is_known(channel_id: StringName) -> bool:
	return channel_id in ALL
