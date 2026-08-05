extends Node3D
class_name GameInventoryEquipmentExample

signal equipment_example_completed(result: GameCommandResult)

# ======= CONSTS =========
const SPEED_EFFECT: GameEffectDefinition = preload("res://content/gameplay/example/shared/effect_speed_boost_example.tres")
const SPEED_ABILITY: GameAbilityDefinition = preload("res://content/gameplay/example/shared/ability_speed_focus_example.tres")
const ITEM_INSTANCE_ID: StringName = &"example.item.boots.instance_001"

# ======== EXPORT =========
@export var inventory_adapter: GameInventoryAdapter = null
@export var owner_kernel: GameObjectKernel = null
@export var auto_equip: bool = true

# ======== PRIVATE VAR ======
var _last_result: GameCommandResult = null

# ======= OVERRIDE =======
func _ready() -> void:
	if auto_equip:
		equip_example_item()

# ====== PUBLIC ========
func equip_example_item() -> GameCommandResult:
	if inventory_adapter == null:
		_last_result = GameCommandResult.invalid_target("Inventory adapter is not assigned.")
	else:
		var effects_to_apply: Array[GameEffectDefinition] = [SPEED_EFFECT]
		var abilities_to_grant: Array[GameAbilityDefinition] = [SPEED_ABILITY]
		_last_result = inventory_adapter.apply_equipment(ITEM_INSTANCE_ID, effects_to_apply, abilities_to_grant)
	equipment_example_completed.emit(_last_result)
	return _last_result

func unequip_example_item() -> GameCommandResult:
	if inventory_adapter == null:
		_last_result = GameCommandResult.invalid_target("Inventory adapter is not assigned.")
	else:
		_last_result = inventory_adapter.remove_equipment(ITEM_INSTANCE_ID)
	equipment_example_completed.emit(_last_result)
	return _last_result

func get_last_result() -> GameCommandResult:
	return _last_result

func get_binding_snapshot() -> Dictionary:
	return inventory_adapter.get_bindings_snapshot() if inventory_adapter != null else {}

func get_owner_speed() -> float:
	if owner_kernel == null or owner_kernel.get_object_context() == null:
		return 0.0
	var attributes: GameAttributes = owner_kernel.get_object_context().get_capability(GameCapabilityIds.ATTRIBUTES_QUERY) as GameAttributes
	return attributes.get_value(&"example.attribute.movement_speed", 0.0) if attributes != null else 0.0

func activate_granted_ability() -> GameCommandResult:
	if owner_kernel == null or owner_kernel.get_object_context() == null:
		return GameCommandResult.invalid_target("Inventory example owner is unresolved.")
	var context: GameObjectContext = owner_kernel.get_object_context()
	var abilities: GameAbilities = context.get_capability(GameCapabilityIds.ABILITIES_ACTIVATE) as GameAbilities
	if abilities == null:
		return GameCommandResult.missing_capability(GameCapabilityIds.ABILITIES_ACTIVATE)
	var execution_context: GameExecutionContext = context.create_root_execution_context(&"example.inventory.activate", "Inventory-granted ability")
	var request := GameAbilityActivationRequest.new(SPEED_ABILITY.ability_id, context.get_object_handle(), execution_context, context.get_object_handle())
	return abilities.activate(request)
