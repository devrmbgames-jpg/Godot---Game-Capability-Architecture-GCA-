@tool
extends Resource
## Inspector configuration for one initial ability-slot assignment.
##
## The ability must already be granted by [GameAbilities]. Runtime item/effect grants
## should bind the returned grant handle through [GameAbilityLoadout.bind_grant].
class_name GameAbilitySlotDefinition

# ======== EXPORT =========
@export var slot_id: StringName = &""
@export var ability: GameAbilityDefinition = null
@export var priority: int = 0

# ====== PUBLIC ========
## Returns whether the initial slot definition can be resolved.
func is_valid() -> bool:
	return not slot_id.is_empty() and ability != null and ability.is_valid()
