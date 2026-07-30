extends RefCounted
class_name GameCapabilityIds

# ======= CONSTS =========
const OBJECT_IDENTITY: StringName = &"object.identity"
const TAGS_QUERY: StringName = &"tags.query"
const TAGS_MODIFY: StringName = &"tags.modify"

const ATTRIBUTES_PROVIDER: StringName = &"attributes.provider"
const ATTRIBUTES_QUERY: StringName = &"attributes.query"
const ATTRIBUTES_MODIFY: StringName = &"attributes.modify"
const METERS_PROVIDER: StringName = &"meters.provider"
const METERS_QUERY: StringName = &"meters.query"
const METERS_MODIFY: StringName = &"meters.modify"
const EFFECTS_RECEIVER: StringName = &"effects.receiver"
const EFFECTS_QUERY: StringName = &"effects.query"
const EFFECTS_DISPEL: StringName = &"effects.dispel"
const EFFECTS_SCHEDULER_HOST: StringName = &"effects.scheduler_host"
const ABILITIES_OWNER: StringName = &"abilities.owner"
const CONTROL_ENDPOINT: StringName = &"control.endpoint"
const MOVEMENT_MOTOR: StringName = &"movement.motor"
const DAMAGE_RECEIVER: StringName = &"damage.receiver"
const DEATH_POLICY: StringName = &"death.policy"
const INTERACTION_TARGET: StringName = &"interaction.target"
const INVENTORY_OWNER: StringName = &"inventory.owner"

const TEST_COUNTER: StringName = &"test.counter"
const TEST_CHAIN: StringName = &"test.chain"
const TEST_MULTI: StringName = &"test.multi"

const ALL: Array[StringName] = [
	OBJECT_IDENTITY,
	TAGS_QUERY,
	TAGS_MODIFY,
	ATTRIBUTES_PROVIDER,
	ATTRIBUTES_QUERY,
	ATTRIBUTES_MODIFY,
	METERS_PROVIDER,
	METERS_QUERY,
	METERS_MODIFY,
	EFFECTS_RECEIVER,
	EFFECTS_QUERY,
	EFFECTS_DISPEL,
	EFFECTS_SCHEDULER_HOST,
	ABILITIES_OWNER,
	CONTROL_ENDPOINT,
	MOVEMENT_MOTOR,
	DAMAGE_RECEIVER,
	DEATH_POLICY,
	INTERACTION_TARGET,
	INVENTORY_OWNER,
	TEST_COUNTER,
	TEST_CHAIN,
	TEST_MULTI,
]

# ====== PUBLIC ========
static func is_known(capability_id: StringName) -> bool:
	return capability_id in ALL
