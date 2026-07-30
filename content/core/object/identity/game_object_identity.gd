@tool
extends GameFeature
class_name GameObjectIdentity

# ======== EXPORT =========
@export var stable_id: StringName = &""
@export var definition_id: StringName = &""
@export var category_tags: Array[StringName] = []
@export var authority_owner: StringName = &""
@export var allow_runtime_generated_id: bool = false

# ======== PRIVATE VAR ======
var _object_handle: GameObjectHandle = null

# ======= OVERRIDE =======
func _init() -> void:
    if feature_id.is_empty():
        feature_id = &"object.identity"
    if provided_capabilities.is_empty():
        var spec := GameCapabilitySpec.new()
        spec.capability_id = GameCapabilityIds.OBJECT_IDENTITY
        spec.cardinality = GameCapabilityCardinality.Type.EXCLUSIVE
        provided_capabilities = [spec]

func _get_configuration_warnings() -> PackedStringArray:
    var warnings: PackedStringArray = super()
    if stable_id.is_empty() and not allow_runtime_generated_id:
        warnings.append("GameObjectIdentity requires a stable_id or allow_runtime_generated_id.")
    if not stable_id.is_empty() and _has_duplicate_stable_id_in_owned_scene():
        warnings.append("Duplicate stable_id '%s' exists in the current owned scene." % stable_id)
    return warnings

# ====== HELPERS ========
func _has_duplicate_stable_id_in_owned_scene() -> bool:
    var scene_root: Node = owner
    if scene_root == null:
        return false
    var matches: int = 0
    var pending: Array[Node] = [scene_root]
    while not pending.is_empty():
        var current: Node = pending.pop_back()
        if current is GameObjectIdentity and (current as GameObjectIdentity).stable_id == stable_id:
            matches += 1
            if matches > 1:
                return true
        for child: Node in current.get_children():
            pending.append(child)
    return false

# ====== PUBLIC ========
func prepare_identity(object_root: Node, kernel: GameObjectKernel) -> GameCommandResult:
    if stable_id.is_empty():
        if not allow_runtime_generated_id:
            return GameCommandResult.configuration_error(&"missing_stable_id", "GameObjectIdentity has no stable_id.")
        stable_id = StringName("runtime.%s" % object_root.get_instance_id())
    _object_handle = GameObjectHandle.new(stable_id, object_root.get_instance_id())
    _object_handle.resolve(object_root, kernel)
    return GameCommandResult.success_changed(&"identity_prepared", _object_handle)

func get_object_handle() -> GameObjectHandle:
    return _object_handle

func invalidate_handle() -> void:
    if _object_handle != null:
        _object_handle.invalidate()

func generate_stable_id(prefix: String = "object") -> StringName:
    var generated: String = "%s.%s" % [prefix, Resource.generate_scene_unique_id()]
    stable_id = StringName(generated)
    update_configuration_warnings()
    return stable_id
