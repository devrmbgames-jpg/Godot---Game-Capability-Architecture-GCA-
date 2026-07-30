@tool
extends Resource
class_name GameCapabilityDependency

# ======== EXPORT =========
@export var capability_id: StringName = &""
@export var required: bool = true
@export_enum("Exclusive", "Optional Exclusive", "Multi") var expected_cardinality: int = GameCapabilityCardinality.Type.EXCLUSIVE
@export var expected_contract: Script = null
@export var lazy_resolution: bool = false
@export_enum("Deactivate Feature", "Configuration Error", "Keep Last Reference", "Ignore Optional") var loss_policy: int = GameCapabilityLossPolicy.Type.DEACTIVATE_FEATURE

# ====== PUBLIC ========
func is_valid() -> bool:
    return not capability_id.is_empty()
