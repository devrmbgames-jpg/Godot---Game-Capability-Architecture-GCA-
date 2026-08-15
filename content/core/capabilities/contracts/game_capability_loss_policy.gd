extends RefCounted
## Defines policies applied when a feature loses a previously resolved capability provider.
class_name GameCapabilityLossPolicy

# ======= ENUMS =========
enum Type {
	DEACTIVATE_FEATURE,
	CONFIGURATION_ERROR,
	KEEP_LAST_REFERENCE,
	IGNORE_OPTIONAL,
}
