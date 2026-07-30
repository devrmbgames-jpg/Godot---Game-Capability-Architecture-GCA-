@tool
extends GameFeature
class_name GameDeathPolicy

signal died(execution_context: GameExecutionContext)

# ======== EXPORT =========
@export var watched_meter_id: StringName = &"health"
@export var dead_tag_id: StringName = &"state.dead"
@export var revivable: bool = false

# ======== PRIVATE VAR ======
var _is_dead: bool = false
var _dead_tag_handle: GameTagSourceHandle = null
var _tags: GameTagContainer = null
var _meters: GameMeters = null

# ======= OVERRIDE =======
func _init() -> void:
	feature_id = &"object.death_policy"
	if provided_capabilities.is_empty():
		var spec := GameCapabilitySpec.new(); spec.capability_id = GameCapabilityIds.DEATH_POLICY; spec.cardinality = GameCapabilityCardinality.Type.EXCLUSIVE; provided_capabilities.append(spec)
	if required_dependencies.is_empty():
		var meter_dependency := GameCapabilityDependency.new(); meter_dependency.capability_id = GameCapabilityIds.METERS_QUERY; meter_dependency.required = true; required_dependencies.append(meter_dependency)
	if optional_dependencies.is_empty():
		var tags_dependency := GameCapabilityDependency.new(); tags_dependency.capability_id = GameCapabilityIds.TAGS_MODIFY; tags_dependency.required = false; optional_dependencies.append(tags_dependency)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = super()
	if watched_meter_id.is_empty(): warnings.append("GameDeathPolicy requires watched_meter_id.")
	if dead_tag_id.is_empty(): warnings.append("GameDeathPolicy requires dead_tag_id.")
	return warnings

func on_game_initialize() -> GameCommandResult:
	_meters = get_dependency(GameCapabilityIds.METERS_QUERY) as GameMeters
	_tags = get_dependency(GameCapabilityIds.TAGS_MODIFY) as GameTagContainer
	if _meters == null or not _meters.has_meter(watched_meter_id): return GameCommandResult.configuration_error(&"missing_death_meter", "Death policy watched meter is unavailable.")
	_is_dead = false
	return GameCommandResult.success_changed(&"death_policy_initialized")

func on_local_event(event: GameLocalEvent) -> void:
	if event.get_event_type_id() != &"meter_depleted": return
	if event.get_payload().get("meter_id", &"") != watched_meter_id: return
	_transition_to_dead(event.get_execution_context())

func on_game_shutdown() -> void:
	if _dead_tag_handle != null and _tags != null: _tags.remove_tag(_dead_tag_handle, false)
	_dead_tag_handle = null

# ====== HELPERS ========
func _transition_to_dead(execution_context: GameExecutionContext) -> void:
	if _is_dead: return
	_is_dead = true
	if _tags != null: _dead_tag_handle = _tags.add_tag(dead_tag_id, &"death.policy")
	var context: GameObjectContext = get_context()
	if context != null: publish_local_event(GameLocalEvent.new(&"died", context.get_object_handle(), execution_context, {"meter_id": watched_meter_id, "revivable": revivable}))
	died.emit(execution_context)

# ====== PUBLIC ========
func is_dead() -> bool: return _is_dead
func revive(execution_context: GameExecutionContext) -> GameCommandResult:
	if not revivable: return GameCommandResult.rejected_permanent(&"not_revivable", "Death policy does not allow revive.")
	if not _is_dead: return GameCommandResult.success_unchanged(&"already_alive")
	_is_dead = false
	if _dead_tag_handle != null and _tags != null: _tags.remove_tag(_dead_tag_handle)
	_dead_tag_handle = null
	var context: GameObjectContext = get_context()
	if context != null: publish_local_event(GameLocalEvent.new(&"revived", context.get_object_handle(), execution_context, {"meter_id": watched_meter_id}))
	return GameCommandResult.success_changed(&"revived")
