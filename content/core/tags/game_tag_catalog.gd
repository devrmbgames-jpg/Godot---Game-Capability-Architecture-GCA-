@tool
extends Resource
## Project-extensible catalog of gameplay tag identifiers not defined by [GameTagIds].
##
## The catalog is an immutable definition at runtime and is used for editor and component
## validation of game-specific tags.
class_name GameTagCatalog

# ======== EXPORT =========
@export var tag_ids: Array[StringName] = []

# ====== PUBLIC ========
## Returns whether [param tag_id] exists in this catalog.
func has_tag(tag_id: StringName) -> bool:
	return tag_id in tag_ids

## Returns validation messages for empty and duplicate tag identifiers.
func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	for tag_id: StringName in tag_ids:
		if tag_id.is_empty():
			errors.append("Tag catalog contains an empty tag ID.")
		elif seen.has(tag_id):
			errors.append("Tag catalog contains duplicate tag '%s'." % tag_id)
		else:
			seen[tag_id] = true
	return errors
