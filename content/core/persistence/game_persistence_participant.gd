extends RefCounted
## Callback-backed persistence contract for one stateful object component.
##
## Identifies an object/component schema and delegates capture, migration,
## restoration, and post-restore reference resolution to typed callbacks.
class_name GamePersistenceParticipant

# ======== PRIVATE VAR ======
var object_id: StringName = &""
var component_id: StringName = &""
var schema_version: int = 1
var capture_callback: Callable = Callable()
var restore_callback: Callable = Callable()
var migrate_callback: Callable = Callable()
var post_restore_callback: Callable = Callable()

# ====== PUBLIC ========
## Returns whether stable IDs and required capture/restore callbacks are configured.
func is_valid() -> bool:
	return not object_id.is_empty() and not component_id.is_empty() and capture_callback.is_valid() and restore_callback.is_valid()

## Captures and deep-copies this component's current snapshot data.
func capture_snapshot() -> Dictionary:
	var value: Variant = capture_callback.call()
	return value.duplicate(true) if value is Dictionary else {}

## Migrates [param data] from [param source_version] to [member schema_version].
## Returns an empty dictionary when migration is required but unavailable or invalid.
func migrate_snapshot(data: Dictionary, source_version: int) -> Dictionary:
	if source_version == schema_version:
		return data.duplicate(true)
	if not migrate_callback.is_valid():
		return {}
	var value: Variant = migrate_callback.call(data.duplicate(true), source_version, schema_version)
	return value.duplicate(true) if value is Dictionary else {}

## Restores a deep copy of snapshot data and requires a structured command result.
func restore_snapshot(data: Dictionary) -> GameCommandResult:
	var value: Variant = restore_callback.call(data.duplicate(true))
	return value as GameCommandResult if value is GameCommandResult else GameCommandResult.configuration_error(&"invalid_restore_result", "Restore callback must return GameCommandResult.")

## Resolves cross-object references after local component state has been restored.
func post_restore(resolver: GameObjectResolver) -> GameCommandResult:
	if not post_restore_callback.is_valid():
		return GameCommandResult.success_unchanged(&"no_post_restore")
	var value: Variant = post_restore_callback.call(resolver)
	return value as GameCommandResult if value is GameCommandResult else GameCommandResult.configuration_error(&"invalid_post_restore_result", "Post restore must return GameCommandResult.")
