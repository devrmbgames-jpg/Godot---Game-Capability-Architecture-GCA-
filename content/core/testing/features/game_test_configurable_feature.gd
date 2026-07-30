extends GameFeature
class_name GameTestConfigurableFeature

# ====== PUBLIC ========
func configure(
    configured_feature_id: StringName,
    provided_capability_id: StringName,
    required_capability_id: StringName = &"",
    cardinality: int = GameCapabilityCardinality.Type.EXCLUSIVE
) -> void:
    feature_id = configured_feature_id
    provided_capabilities.clear()
    required_dependencies.clear()
    if not provided_capability_id.is_empty():
        var spec := GameCapabilitySpec.new()
        spec.capability_id = provided_capability_id
        spec.cardinality = cardinality
        provided_capabilities.append(spec)
    if not required_capability_id.is_empty():
        var dependency := GameCapabilityDependency.new()
        dependency.capability_id = required_capability_id
        dependency.required = true
        dependency.expected_cardinality = GameCapabilityCardinality.Type.EXCLUSIVE
        required_dependencies.append(dependency)
