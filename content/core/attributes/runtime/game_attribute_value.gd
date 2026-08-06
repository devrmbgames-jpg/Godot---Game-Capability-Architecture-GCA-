extends RefCounted
## Runtime state and cached calculation for one gameplay attribute.
##
## Aggregates valid [GameAttributeModifier] instances with the formula
## [code](base + add) * (1.0 + increase)[/code], then applies the definition clamp.
class_name GameAttributeValue

# ======== PRIVATE VAR ======
var _definition: GameAttributeDefinition = null
var _base: float = 0.0
var _add: float = 0.0
var _increase: float = 0.0
var _unclamped_final: float = 0.0
var _final: float = 0.0
var _dirty: bool = true
var _version: int = 0
var _modifiers: Dictionary = {}

# ======= OVERRIDE =======
## Creates runtime state from [param definition] and an optional base override.
func _init(definition: GameAttributeDefinition, base_override: Variant = null) -> void:
	_definition = definition
	_base = definition.default_base if base_override == null else float(base_override)

# ====== HELPERS ========
func _sort_modifiers(a: GameAttributeModifier, b: GameAttributeModifier) -> bool:
	if a.get_priority() != b.get_priority(): return a.get_priority() < b.get_priority()
	if a.get_source_id() != b.get_source_id(): return String(a.get_source_id()) < String(b.get_source_id())
	return a.get_creation_index() < b.get_creation_index()

func _recalculate() -> void:
	if not _dirty: return
	_add = 0.0
	_increase = 0.0
	var values: Array[GameAttributeModifier] = []
	for modifier: GameAttributeModifier in _modifiers.values():
		if modifier.is_valid(): values.append(modifier)
	values.sort_custom(_sort_modifiers)
	for modifier: GameAttributeModifier in values:
		if modifier.get_operation() == GameAttributeModifier.Operation.ADD:
			_add += modifier.get_magnitude()
		else:
			_increase += modifier.get_magnitude()
	_unclamped_final = (_base + _add) * (1.0 + _increase)
	_final = _definition.clamp_value(_unclamped_final)
	_dirty = false
	_version += 1

# ====== PUBLIC ========
## Returns the immutable definition used by this runtime value.
func get_definition() -> GameAttributeDefinition: return _definition
## Returns the current base layer before modifiers.
func get_base() -> float: return _base
## Replaces the base layer and invalidates the cached final value.
func set_base(value: float) -> void: _base = value; _dirty = true
## Adds or replaces a modifier by its handle and marks the value dirty.
func add_modifier(modifier: GameAttributeModifier) -> void: _modifiers[modifier.get_handle_id()] = modifier; _dirty = true
## Removes and invalidates the modifier identified by [param handle_id].
## Returns [code]true[/code] when a modifier was removed.
func remove_modifier(handle_id: int) -> bool:
	if not _modifiers.has(handle_id): return false
	var modifier: GameAttributeModifier = _modifiers[handle_id]
	modifier.invalidate()
	_modifiers.erase(handle_id)
	_dirty = true
	return true
## Updates one modifier magnitude without changing its handle.
func update_modifier(handle_id: int, magnitude: float) -> bool:
	if not _modifiers.has(handle_id): return false
	(_modifiers[handle_id] as GameAttributeModifier).set_magnitude(magnitude)
	_dirty = true
	return true
## Returns the clamped final value, recalculating only when dirty.
func get_final() -> float: _recalculate(); return _final
## Returns the calculation version after ensuring the cache is current.
func get_version() -> int: _recalculate(); return _version
## Returns a diagnostic breakdown of base, modifier layers, final value, and sources.
func get_debug_snapshot() -> Dictionary:
	_recalculate()
	var breakdown: Array[Dictionary] = []
	for modifier: GameAttributeModifier in _modifiers.values():
		breakdown.append({"handle_id": modifier.get_handle_id(), "operation": modifier.get_operation(), "magnitude": modifier.get_magnitude(), "source_id": modifier.get_source_id()})
	return {"base": _base, "add": _add, "increase": _increase, "unclamped_final": _unclamped_final, "final": _final, "version": _version, "modifiers": breakdown}
