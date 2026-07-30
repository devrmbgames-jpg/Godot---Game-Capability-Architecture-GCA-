extends GameFeature
class_name GameTestMultiProviderFeature

# ======== EXPORT =========
@export var provider_label: StringName = &"provider"

# ======= OVERRIDE =======
func _init() -> void:
    allow_multiple_instances = true
    if provided_capabilities.is_empty():
        var spec := GameCapabilitySpec.new()
        spec.capability_id = GameCapabilityIds.TEST_MULTI
        spec.cardinality = GameCapabilityCardinality.Type.MULTI
        provided_capabilities = [spec]
