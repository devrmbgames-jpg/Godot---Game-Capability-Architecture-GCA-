extends RefCounted
class_name GameCapabilityCardinality

# ======= ENUMS =========
enum Type {
    EXCLUSIVE,
    OPTIONAL_EXCLUSIVE,
    MULTI,
}

# ====== PUBLIC ========
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
