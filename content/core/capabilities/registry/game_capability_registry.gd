extends RefCounted
class_name GameCapabilityRegistry

# ======== PRIVATE VAR ======
var _providers: Dictionary = {}
var _cardinalities: Dictionary = {}

# ====== HELPERS ========
func _validate_contract(provider: GameFeature, expected_contract: Script) -> bool:
    if expected_contract == null:
        return true
    var provider_script: Script = provider.get_script() as Script
    while provider_script != null:
        if provider_script == expected_contract:
            return true
        provider_script = provider_script.get_base_script()
    return false

# ====== PUBLIC ========
func register_provider(spec: GameCapabilitySpec, provider: GameFeature) -> GameCommandResult:
    if spec == null or not spec.is_valid():
        return GameCommandResult.configuration_error(&"invalid_capability_spec", "Capability specification is invalid.")
    if provider == null:
        return GameCommandResult.configuration_error(&"missing_provider", "Capability provider is null.")

    var providers: Array[GameFeature] = get_all(spec.capability_id)
    var existing_cardinality: int = _cardinalities.get(spec.capability_id, spec.cardinality)
    if provider in providers:
        return GameCommandResult.success_unchanged(&"provider_already_registered")
    if not providers.is_empty() and existing_cardinality != spec.cardinality:
        return GameCommandResult.configuration_error(
            &"cardinality_mismatch",
            "Capability '%s' was declared with incompatible cardinalities." % spec.capability_id
        )
    if spec.cardinality != GameCapabilityCardinality.Type.MULTI and not providers.is_empty():
        return GameCommandResult.configuration_error(
            &"exclusive_provider_conflict",
            "Capability '%s' has more than one exclusive provider." % spec.capability_id
        )

    providers.append(provider)
    _providers[spec.capability_id] = providers
    _cardinalities[spec.capability_id] = spec.cardinality
    return GameCommandResult.success_changed(&"provider_registered")

func unregister_provider(capability_id: StringName, provider: GameFeature) -> bool:
    if not _providers.has(capability_id):
        return false
    var providers: Array[GameFeature] = get_all(capability_id)
    var removed: bool = provider in providers
    providers.erase(provider)
    if providers.is_empty():
        _providers.erase(capability_id)
        _cardinalities.erase(capability_id)
    else:
        _providers[capability_id] = providers
    return removed

func resolve_dependency(dependency: GameCapabilityDependency) -> GameQueryResult:
    if dependency == null or not dependency.is_valid():
        return GameQueryResult.failure(&"invalid_dependency", "Capability dependency is invalid.")

    var providers: Array[GameFeature] = get_all(dependency.capability_id)
    if providers.is_empty():
        if dependency.required:
            return GameQueryResult.failure(
                &"missing_required_capability",
                "Required capability '%s' is missing." % dependency.capability_id
            )
        return GameQueryResult.not_found(&"optional_capability_missing")

    var cardinality: int = get_cardinality(dependency.capability_id)
    if dependency.expected_cardinality != GameCapabilityCardinality.Type.MULTI and providers.size() > 1:
        return GameQueryResult.failure(
            &"unexpected_multi_capability",
            "Capability '%s' resolved to multiple providers." % dependency.capability_id
        )
    if cardinality != dependency.expected_cardinality:
        var exclusive_compatible: bool = (
            cardinality != GameCapabilityCardinality.Type.MULTI
            and dependency.expected_cardinality != GameCapabilityCardinality.Type.MULTI
        )
        if not exclusive_compatible:
            return GameQueryResult.failure(
                &"cardinality_mismatch",
                "Capability '%s' has unexpected cardinality." % dependency.capability_id
            )

    for provider: GameFeature in providers:
        if not _validate_contract(provider, dependency.expected_contract):
            return GameQueryResult.failure(
                &"contract_mismatch",
                "Provider for '%s' does not inherit the expected contract." % dependency.capability_id
            )

    if dependency.expected_cardinality == GameCapabilityCardinality.Type.MULTI:
        return GameQueryResult.found_value(providers)
    return GameQueryResult.found_value(providers[0])

func get_exclusive(capability_id: StringName) -> GameFeature:
    var providers: Array[GameFeature] = get_all(capability_id)
    if providers.is_empty():
        return null
    return providers[0]

func get_all(capability_id: StringName) -> Array[GameFeature]:
    var result: Array[GameFeature] = []
    if not _providers.has(capability_id):
        return result
    for provider: GameFeature in _providers[capability_id]:
        if is_instance_valid(provider):
            result.append(provider)
    return result

func has_capability(capability_id: StringName) -> bool:
    return not get_all(capability_id).is_empty()

func get_cardinality(capability_id: StringName) -> int:
    return _cardinalities.get(capability_id, GameCapabilityCardinality.Type.OPTIONAL_EXCLUSIVE)

func clear() -> void:
    _providers.clear()
    _cardinalities.clear()

func get_debug_snapshot() -> Dictionary:
    var snapshot: Dictionary = {}
    var capability_ids: Array = _providers.keys()
    capability_ids.sort()
    for capability_id: StringName in capability_ids:
        var provider_ids: Array[StringName] = []
        for provider: GameFeature in get_all(capability_id):
            provider_ids.append(provider.feature_id)
        snapshot[capability_id] = {
            "cardinality": GameCapabilityCardinality.to_label(get_cardinality(capability_id)),
            "providers": provider_ids,
        }
    return snapshot
