extends RefCounted
## Central catalog of framework-level gameplay tag identifiers used by GCA examples and policies.
##
## Game-specific tags should normally live in [GameTagCatalog] resources rather than being
## scattered as string literals throughout gameplay code.
class_name GameTagIds

# ======= CONSTS =========
const STATE_DEAD: StringName = &"state.dead"
const STATE_DISABLED: StringName = &"state.disabled"
const STATUS_BURNING: StringName = &"status.burning"
const TRAIT_FLAMMABLE: StringName = &"trait.flammable"
const FACTION_PLAYER: StringName = &"faction.player"
const OBJECT_PROP_BARREL: StringName = &"object.prop.barrel"
const ABILITY_BLOCKED_MOVEMENT: StringName = &"ability.blocked.movement"

const ALL: Array[StringName] = [
	STATE_DEAD,
	STATE_DISABLED,
	STATUS_BURNING,
	TRAIT_FLAMMABLE,
	FACTION_PLAYER,
	OBJECT_PROP_BARREL,
	ABILITY_BLOCKED_MOVEMENT,
]

# ====== PUBLIC ========
## Returns whether [param tag_id] is part of the framework tag catalog.
static func is_known(tag_id: StringName) -> bool:
	return tag_id in ALL
