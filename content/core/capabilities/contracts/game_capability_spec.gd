@tool
extends Resource
## Declares one capability provided by a [GameFeature] and its registration cardinality.
class_name GameCapabilitySpec

# ======== EXPORT =========
@export var capability_id: StringName = &""
@export_enum("Exclusive", "Optional Exclusive", "Multi") var cardinality: int = GameCapabilityCardinality.Type.EXCLUSIVE

# ====== PUBLIC ========
## Returns whether this specification has a non-empty capability identifier.
func is_valid() -> bool:
	return not capability_id.is_empty()
