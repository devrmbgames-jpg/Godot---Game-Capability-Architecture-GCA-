@tool
extends Resource
class_name GameCapabilitySpec

# ======== EXPORT =========
@export var capability_id: StringName = &""
@export_enum("Exclusive", "Optional Exclusive", "Multi") var cardinality: int = GameCapabilityCardinality.Type.EXCLUSIVE

# ====== PUBLIC ========
func is_valid() -> bool:
    return not capability_id.is_empty()
