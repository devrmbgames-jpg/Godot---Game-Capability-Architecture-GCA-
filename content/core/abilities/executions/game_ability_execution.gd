extends RefCounted
## Runtime state machine for one ability activation.
##
## Owns the selected grant, normalized request, operation position, prepared cost
## records, execution-owned tags, terminal state, and failure reason.
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
## Creates an execution bound to one grant, request, and causal context.
func _init(execution_id: int, grant: GameAbilityGrant, request: GameAbilityActivationRequest, execution_context: GameExecutionContext) -> void:
	_execution_id = execution_id
	_grant = grant
	_request = request
	_execution_context = execution_context

# ====== PUBLIC ========
## Returns the owner-local execution ID.
func get_execution_id() -> int: return _execution_id
## Returns the grant used by this execution.
func get_grant() -> GameAbilityGrant: return _grant
## Returns the immutable ability definition associated with the grant.
func get_definition() -> GameAbilityDefinition: return _grant.get_definition() if _grant != null else null
## Returns the normalized activation request.
func get_request() -> GameAbilityActivationRequest: return _request
## Returns the causal execution context.
func get_execution_context() -> GameExecutionContext: return _execution_context
## Returns the current lifecycle state.
func get_state() -> State: return _state
## Changes state unless the execution is already terminal.
func set_state(value: State) -> bool:
	if is_terminal(): return false
	_state = value
	return true
## Returns the index of the next operation to execute.
func get_operation_index() -> int: return _operation_index
## Advances the execution to the next operation.
func advance_operation() -> void: _operation_index += 1
## Stores the stable reason for a failed or cancelled execution.
func set_failure_reason(value: StringName) -> void: _failure_reason = value
## Returns the stored failure reason.
func get_failure_reason() -> StringName: return _failure_reason
## Registers prepared cost data for commit, rollback, or refund handling.
func add_prepared_cost(cost: GameAbilityCost, prepared: Variant) -> void: _prepared_costs.append({&"cost": cost, &"prepared": prepared})
## Returns a copy of prepared cost records.
func get_prepared_costs() -> Array[Dictionary]: return _prepared_costs.duplicate()
## Registers a tag handle owned by this execution.
func add_owned_tag_handle(handle: GameTagSourceHandle) -> void:
	if handle != null: _owned_tag_handles.append(handle)
## Returns a copy of execution-owned tag handles.
func get_owned_tag_handles() -> Array[GameTagSourceHandle]: return _owned_tag_handles.duplicate()
## Returns whether state is completed, cancelled, or failed.
func is_terminal() -> bool: return _state in [State.COMPLETED, State.CANCELLED, State.FAILED]
## Serializes diagnostic execution state and root-operation identity.
func to_dictionary() -> Dictionary:
	return {"execution_id": _execution_id, "ability_id": get_definition().ability_id if get_definition() != null else &"", "grant_handle_id": _grant.get_handle_id() if _grant != null else 0, "state": _state, "operation_index": _operation_index, "failure_reason": _failure_reason, "root_operation_id": _execution_context.get_root_operation_id() if _execution_context != null else 0}
