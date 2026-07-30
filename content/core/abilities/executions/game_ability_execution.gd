extends RefCounted
class_name GameAbilityExecution

# ======= ENUMS =========
enum State { REQUESTED, VALIDATED, PREPARED, COMMITTED, EXECUTING, WAITING, COMPLETED, CANCELLED, FAILED }

# ======== PRIVATE VAR ======
var _execution_id: int = 0
var _grant: GameAbilityGrant = null
var _request: GameAbilityActivationRequest = null
var _execution_context: GameExecutionContext = null
var _state: State = State.REQUESTED
var _operation_index: int = 0
var _failure_reason: StringName = &""
var _prepared_costs: Array[Dictionary] = []
var _owned_tag_handles: Array[GameTagSourceHandle] = []

# ======= OVERRIDE =======
func _init(execution_id: int, grant: GameAbilityGrant, request: GameAbilityActivationRequest, execution_context: GameExecutionContext) -> void:
	_execution_id = execution_id
	_grant = grant
	_request = request
	_execution_context = execution_context

# ====== PUBLIC ========
func get_execution_id() -> int: return _execution_id
func get_grant() -> GameAbilityGrant: return _grant
func get_definition() -> GameAbilityDefinition: return _grant.get_definition() if _grant != null else null
func get_request() -> GameAbilityActivationRequest: return _request
func get_execution_context() -> GameExecutionContext: return _execution_context
func get_state() -> State: return _state
func set_state(value: State) -> bool:
	if is_terminal(): return false
	_state = value
	return true
func get_operation_index() -> int: return _operation_index
func advance_operation() -> void: _operation_index += 1
func set_failure_reason(value: StringName) -> void: _failure_reason = value
func get_failure_reason() -> StringName: return _failure_reason
func add_prepared_cost(cost: GameAbilityCost, prepared: Variant) -> void: _prepared_costs.append({"cost": cost, "prepared": prepared})
func get_prepared_costs() -> Array[Dictionary]: return _prepared_costs.duplicate()
func add_owned_tag_handle(handle: GameTagSourceHandle) -> void:
	if handle != null: _owned_tag_handles.append(handle)
func get_owned_tag_handles() -> Array[GameTagSourceHandle]: return _owned_tag_handles.duplicate()
func is_terminal() -> bool: return _state in [State.COMPLETED, State.CANCELLED, State.FAILED]
func to_dictionary() -> Dictionary:
	return {"execution_id": _execution_id, "ability_id": get_definition().ability_id if get_definition() != null else &"", "grant_handle_id": _grant.get_handle_id() if _grant != null else 0, "state": _state, "operation_index": _operation_index, "failure_reason": _failure_reason, "root_operation_id": _execution_context.get_root_operation_id() if _execution_context != null else 0}
