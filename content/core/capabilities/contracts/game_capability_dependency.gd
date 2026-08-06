@tool
extends Resource
## Describes a capability dependency requested by a [GameFeature].
##
## The contract records requiredness, expected cardinality, optional script type checks,
## lazy resolution, and the policy used when a previously resolved provider is lost.
class_name GameCapabilityDependency

# ======== EXPORT =========
@export var capability_id: StringName = &""
@export var required: bool = true
@export_enum("Exclusive", "Optional Exclusive", "Multi") var expected_cardinality: int = GameCapabilityCardinality.Type.EXCLUSIVE
@export var expected_contract: Script = null
@export var lazy_resolution: bool = false
@export_enum("Deactivate Feature", "Configuration Error", "Keep Last Reference", "Ignore Optional") var loss_policy: int = GameCapabilityLossPolicy.Type.DEACTIVATE_FEATURE

# ====== PUBLIC ========
## Returns whether this dependency has a non-empty capability identifier.
func is_valid() -> bool:
	return not capability_id.is_empty()
