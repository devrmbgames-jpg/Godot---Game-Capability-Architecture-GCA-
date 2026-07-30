@tool
extends GameFeature
class_name GameTagContainer

# ======== EXPORT =========
@export var permanent_tags: Array[StringName] = []
@export var tag_catalog: GameTagCatalog = null
@export var reject_unknown_tags: bool = true

# ======== PRIVATE VAR ======
var _sources_by_tag: Dictionary = {}
var _handles_by_id: Dictionary = {}
var _handle_counter: int = 0

# ======= OVERRIDE =======
func _init() -> void:
    if feature_id.is_empty():
        feature_id = &"object.tags"
    if provided_capabilities.is_empty():
        var query_spec := GameCapabilitySpec.new()
        query_spec.capability_id = GameCapabilityIds.TAGS_QUERY
        query_spec.cardinality = GameCapabilityCardinality.Type.EXCLUSIVE
        var modify_spec := GameCapabilitySpec.new()
        modify_spec.capability_id = GameCapabilityIds.TAGS_MODIFY
        modify_spec.cardinality = GameCapabilityCardinality.Type.EXCLUSIVE
        provided_capabilities = [query_spec, modify_spec]

func _get_configuration_warnings() -> PackedStringArray:
    var warnings: PackedStringArray = super()
    if tag_catalog != null:
        warnings.append_array(tag_catalog.get_validation_errors())
    for tag_id: StringName in permanent_tags:
        if tag_id.is_empty():
            warnings.append("GameTagContainer contains an empty permanent tag.")
        elif reject_unknown_tags and not _is_tag_known(tag_id):
            warnings.append("Unknown gameplay tag '%s'." % tag_id)
    return warnings

# ====== HELPERS ========
func _is_tag_known(tag_id: StringName) -> bool:
    if GameTagIds.is_known(tag_id):
        return true
    return tag_catalog != null and tag_catalog.has_tag(tag_id)

func _emit_tag_event(event_type_id: StringName, handle: GameTagSourceHandle) -> void:
    var context: GameObjectContext = get_context()
    if context == null:
        return
    var execution_context: GameExecutionContext = context.create_root_execution_context(event_type_id, event_type_id)
    var event := GameLocalEvent.new(
        event_type_id,
        context.get_object_handle(),
        execution_context,
        {
            "tag_id": handle.get_tag_id(),
            "source_id": handle.get_source_id(),
            "handle_id": handle.get_handle_id(),
        }
    )
    publish_local_event(event)

# ====== PUBLIC ========
func on_game_initialize() -> GameCommandResult:
    _sources_by_tag.clear()
    _handles_by_id.clear()
    _handle_counter = 0
    for tag_id: StringName in permanent_tags:
        var handle: GameTagSourceHandle = add_tag(tag_id, &"scene.permanent", true, false)
        if handle == null:
            return GameCommandResult.configuration_error(&"invalid_permanent_tag", "Permanent tag '%s' is invalid." % tag_id)
    return GameCommandResult.success_changed(&"tags_initialized")

func on_game_shutdown() -> void:
    for handle: GameTagSourceHandle in _handles_by_id.values():
        handle.invalidate()
    _sources_by_tag.clear()
    _handles_by_id.clear()

func add_tag(tag_id: StringName, source_id: StringName, persistent: bool = false, emit_event: bool = true) -> GameTagSourceHandle:
    if tag_id.is_empty() or source_id.is_empty():
        return null
    if reject_unknown_tags and not _is_tag_known(tag_id):
        return null
    _handle_counter += 1
    var handle := GameTagSourceHandle.new(_handle_counter, tag_id, source_id, persistent)
    var sources: Dictionary = _sources_by_tag.get(tag_id, {})
    sources[handle.get_handle_id()] = handle
    _sources_by_tag[tag_id] = sources
    _handles_by_id[handle.get_handle_id()] = handle
    if emit_event and get_lifecycle_state() == LifecycleState.ACTIVATED:
        _emit_tag_event(&"tag_added", handle)
    return handle

func remove_tag(handle: GameTagSourceHandle, emit_event: bool = true) -> bool:
    if handle == null or not handle.is_valid():
        return false
    var tag_id: StringName = handle.get_tag_id()
    if not _sources_by_tag.has(tag_id):
        handle.invalidate()
        return false
    var sources: Dictionary = _sources_by_tag[tag_id]
    var removed: bool = sources.erase(handle.get_handle_id())
    _handles_by_id.erase(handle.get_handle_id())
    handle.invalidate()
    if sources.is_empty():
        _sources_by_tag.erase(tag_id)
    else:
        _sources_by_tag[tag_id] = sources
    if removed and emit_event and get_lifecycle_state() == LifecycleState.ACTIVATED:
        _emit_tag_event(&"tag_removed", handle)
    return removed

func has_exact_tag(tag_id: StringName) -> bool:
    return _sources_by_tag.has(tag_id) and not (_sources_by_tag[tag_id] as Dictionary).is_empty()

func has_tag_or_child(parent_tag_id: StringName) -> bool:
    if has_exact_tag(parent_tag_id):
        return true
    var prefix: String = "%s." % parent_tag_id
    for tag_id: StringName in _sources_by_tag.keys():
        if String(tag_id).begins_with(prefix):
            return true
    return false

func get_source_handles(tag_id: StringName) -> Array[GameTagSourceHandle]:
    var result: Array[GameTagSourceHandle] = []
    if not _sources_by_tag.has(tag_id):
        return result
    for handle: GameTagSourceHandle in (_sources_by_tag[tag_id] as Dictionary).values():
        if handle.is_valid():
            result.append(handle)
    return result

func get_debug_snapshot() -> Dictionary:
    var snapshot: Dictionary = {}
    var tag_ids: Array = _sources_by_tag.keys()
    tag_ids.sort()
    for tag_id: StringName in tag_ids:
        var sources: Array[Dictionary] = []
        for handle: GameTagSourceHandle in get_source_handles(tag_id):
            sources.append({
                "handle_id": handle.get_handle_id(),
                "source_id": handle.get_source_id(),
                "persistent": handle.is_persistent(),
            })
        snapshot[tag_id] = sources
    return snapshot
