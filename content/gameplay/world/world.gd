extends Node3D
class_name GameWorldBase

# ======== EXPORT =========
@export var world_context: GameWorldContext = null

# ======= OVERRIDE =======
func _ready() -> void:
	if world_context == null:
		push_error("SimpleScene requires GameWorldContext.")
		return
	
	
	


# ====== HELPERS ========
func _bind_kernel(kernel: GameObjectKernel) -> bool:
	if kernel == null:
		push_error("SimpleScene contains an object without GameObjectKernel.")
		return false
	var result: GameCommandResult = world_context.bind_kernel(kernel)
	if result.is_success():
		return true
	push_error(
		"Could not bind kernel: %s — %s" % [
			result.get_reason_code(),
			result.get_debug_message(),
		]
	)
	return false


# ===== PUBLIC ======
func bind_kernel(kernel: GameObjectKernel) -> bool :
	return _bind_kernel(kernel)
