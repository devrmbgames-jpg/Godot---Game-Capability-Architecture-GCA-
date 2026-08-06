extends RefCounted
## Defines provider cardinality policies for capability registration and dependency resolution.
class_name GameCapabilityCardinality

# ======= ENUMS =========
enum Type {
	EXCLUSIVE,
	OPTIONAL_EXCLUSIVE,
	MULTI,
}

# ====== PUBLIC ========
## Returns a stable diagnostic label for the cardinality [param value].
static func to_label(value: int) -> String:
	match value:
		Type.EXCLUSIVE:
			return "exclusive"
		Type.OPTIONAL_EXCLUSIVE:
			return "optional_exclusive"
		Type.MULTI:
			return "multi"
		_:
			return "unknown"
