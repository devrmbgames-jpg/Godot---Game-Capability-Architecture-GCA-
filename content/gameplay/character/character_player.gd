extends GameCharacterBase
class_name GameCharacterPlayer

# ======= ON READY ========
@onready var _kernel: GameObjectKernel = $GameObjectKernel
@onready var _control_arbiter: GameControlArbiter = $GameObjectKernel/GameControlArbiter
@onready var _control_endpoint: GameControlEndpoint = $GameObjectKernel/GameControlEndpoint
@onready var _player_input_source: GamePlayerInputSource = $GamePlayerInputSource

# ======= OVERRIDE =======
func _ready() -> void:
	if _kernel.get_lifecycle_state() == GameObjectKernel.LifecycleState.ACTIVATED:
		_configure_player_control()
	elif not _kernel.kernel_activated.is_connected(_on_kernel_activated):
		_kernel.kernel_activated.connect(_on_kernel_activated, CONNECT_ONE_SHOT)

func _exit_tree() -> void:
	if _player_input_source != null:
		_player_input_source.detach()

# ====== HELPERS ========
func _configure_player_control() -> void:
	_player_input_source.set_execution_context_factory(
		Callable(self, &"_create_input_execution_context")
	)
	var attach_result: GameCommandResult = _player_input_source.attach(
		_control_endpoint,
		_control_arbiter
	)
	if not attach_result.is_success():
		push_error(
			"Could not attach player control source: %s — %s" % [
				attach_result.get_reason_code(),
				attach_result.get_debug_message(),
			]
		)
		return
	var ownership_results: Dictionary = _player_input_source.request_control()
	for channel_id: StringName in ownership_results.keys():
		var result: GameCommandResult = ownership_results[channel_id] as GameCommandResult
		if result == null or not result.is_success():
			push_error("Player control source could not acquire channel '%s'." % channel_id)

func _create_input_execution_context(
	operation_type_id: StringName,
	description: String
) -> GameExecutionContext:
	return _kernel.create_root_execution_context(operation_type_id, description)

# ===== SLOTS =======
func _on_kernel_activated(_kernel_instance: GameObjectKernel) -> void:
	_configure_player_control()
