@tool
extends Resource
## Player-input mapping from one Godot input action to one logical ability slot.
##
## The binding knows nothing about concrete ability definitions or activation payloads.
## Slot resolution happens later through the controlled object's [GameAbilityLoadout].
class_name GameAbilityInputBinding

# ======== EXPORT =========
@export var input_action: StringName = &""
@export var slot_id: StringName = &""

# ====== PUBLIC ========
## Returns whether both the input action and logical slot are configured.
func is_valid() -> bool:
	return not input_action.is_empty() and not slot_id.is_empty()
