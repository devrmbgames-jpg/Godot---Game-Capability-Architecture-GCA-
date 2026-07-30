@tool
extends Resource
class_name GameTagCatalog

# ======== EXPORT =========
@export var tag_ids: Array[StringName] = []

# ====== PUBLIC ========
func has_tag(tag_id: StringName) -> bool:
    return tag_id in tag_ids

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
