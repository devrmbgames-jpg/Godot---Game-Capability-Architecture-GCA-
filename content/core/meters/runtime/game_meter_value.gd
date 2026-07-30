extends RefCounted
class_name GameMeterValue

# ======== PRIVATE VAR ======
var _definition: GameMeterDefinition = null
var _current: float = 0.0
var _maximum: float = 0.0
var _version: int = 0
var _depleted: bool = false

# ======= OVERRIDE =======
func _init(definition: GameMeterDefinition, maximum: float) -> void:
	_definition = definition
	_maximum = maxf(maximum, definition.minimum)
	match definition.initial_policy:
		GameMeterDefinition.InitialPolicy.EMPTY: _current = definition.minimum
		GameMeterDefinition.InitialPolicy.FIXED: _current = clampf(definition.initial_value, definition.minimum, _maximum)
		_: _current = _maximum
	_depleted = _current <= definition.depletion_threshold

# ====== PUBLIC ========
func get_definition() -> GameMeterDefinition: return _definition
func get_current() -> float: return _current
func get_maximum() -> float: return _maximum
func get_normalized() -> float: return 0.0 if is_zero_approx(_maximum) else clampf(_current / _maximum, 0.0, 1.0)
func is_depleted() -> bool: return _depleted
func get_version() -> int: return _version
func set_current(value: float) -> Dictionary:
	var previous: float = _current
	var was_depleted: bool = _depleted
	_current = clampf(value, _definition.minimum, _maximum)
	_depleted = _current <= _definition.depletion_threshold
	if not is_equal_approx(previous, _current): _version += 1
	return {"previous": previous, "current": _current, "delta": _current - previous, "depleted_crossed": not was_depleted and _depleted, "filled_crossed": previous < _maximum and is_equal_approx(_current, _maximum)}
func set_maximum(value: float, policy: GameMeterDefinition.MaximumChangePolicy) -> Dictionary:
	var previous_maximum: float = _maximum
	var previous_current: float = _current
	var ratio: float = 0.0 if is_zero_approx(previous_maximum) else _current / previous_maximum
	_maximum = maxf(value, _definition.minimum)
	match policy:
		GameMeterDefinition.MaximumChangePolicy.KEEP_PERCENTAGE: _current = _maximum * ratio
		GameMeterDefinition.MaximumChangePolicy.ADJUST_BY_DELTA: _current += _maximum - previous_maximum
		_: pass
	_current = clampf(_current, _definition.minimum, _maximum)
	_depleted = _current <= _definition.depletion_threshold
	_version += 1
	return {"previous_maximum": previous_maximum, "maximum": _maximum, "previous_current": previous_current, "current": _current}
func get_debug_snapshot() -> Dictionary:
	return {"current": _current, "maximum": _maximum, "normalized": get_normalized(), "depleted": _depleted, "version": _version}
