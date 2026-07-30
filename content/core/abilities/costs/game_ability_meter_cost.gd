@tool
extends GameAbilityCost
class_name GameAbilityMeterCost

# ======== EXPORT =========
@export var meter_id: StringName = &""
@export_range(0.0, 1000000.0, 0.01) var amount: float = 0.0

# ====== PUBLIC ========
func can_pay(abilities: GameAbilities, _grant: GameAbilityGrant, _request: GameAbilityActivationRequest) -> GameCommandResult:
	var meters: GameMeters = abilities.get_meters()
	if meters == null:
		return GameCommandResult.missing_capability(GameCapabilityIds.METERS_MODIFY)
	if not meters.has_meter(meter_id):
		return GameCommandResult.configuration_error(&"unknown_cost_meter", "Unknown cost meter '%s'." % meter_id)
	if meters.get_current(meter_id) < amount:
		return GameCommandResult.new(GameCommandResult.Status.INSUFFICIENT_RESOURCE, &"insufficient_meter", "Meter '%s' is insufficient." % meter_id)
	return GameCommandResult.success_unchanged(&"cost_payable")

func prepare(abilities: GameAbilities, _grant: GameAbilityGrant, _request: GameAbilityActivationRequest) -> Variant:
	return abilities.get_meters().get_current(meter_id)

func commit(abilities: GameAbilities, _grant: GameAbilityGrant, request: GameAbilityActivationRequest, _prepared: Variant) -> GameCommandResult:
	return abilities.get_meters().modify_current(meter_id, -amount, request.get_execution_context(), &"ability_cost")

func rollback(abilities: GameAbilities, _grant: GameAbilityGrant, request: GameAbilityActivationRequest, prepared: Variant) -> void:
	var meters: GameMeters = abilities.get_meters()
	if meters != null:
		meters.modify_current(meter_id, float(prepared) - meters.get_current(meter_id), request.get_execution_context(), &"ability_cost_rollback")

func refund(abilities: GameAbilities, _grant: GameAbilityGrant, execution: GameAbilityExecution, _prepared: Variant) -> void:
	if refund_on_cancel and abilities.get_meters() != null:
		abilities.get_meters().modify_current(meter_id, amount, execution.get_execution_context(), &"ability_cost_refund")

func is_valid() -> bool:
	return not meter_id.is_empty() and amount >= 0.0
