extends Node
class_name GameTimeService

signal simulation_advanced(delta: float, simulation_time: float, simulation_step: int)

# ======== EXPORT =========
@export var auto_advance: bool = true
@export_range(0.0, 16.0, 0.01) var time_scale: float = 1.0
@export var paused: bool = false

# ======== PRIVATE VAR ======
var _simulation_time: float = 0.0
var _simulation_step: int = 0

# ======= OVERRIDE =======
func _process(delta: float) -> void:
	if auto_advance and not paused:
		advance(delta)

# ====== PUBLIC ========
func advance(delta: float) -> float:
	if delta <= 0.0 or paused:
		return 0.0
	var scaled_delta: float = delta * time_scale
	_simulation_time += scaled_delta
	_simulation_step += 1
	simulation_advanced.emit(scaled_delta, _simulation_time, _simulation_step)
	return scaled_delta

func get_simulation_time() -> float:
	return _simulation_time

func get_simulation_step() -> int:
	return _simulation_step

func restore_clock(simulation_time: float, simulation_step: int) -> void:
	_simulation_time = maxf(0.0, simulation_time)
	_simulation_step = maxi(0, simulation_step)

func get_debug_snapshot() -> Dictionary:
	return {"simulation_time": _simulation_time, "simulation_step": _simulation_step, "time_scale": time_scale, "paused": paused}
