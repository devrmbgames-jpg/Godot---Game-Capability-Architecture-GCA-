extends RefCounted
class_name GameCapabilityIds

# ======= CONSTS =========
const OBJECT_IDENTITY: StringName = &"object.identity"
const TAGS_QUERY: StringName = &"tags.query"
const TAGS_MODIFY: StringName = &"tags.modify"

const ATTRIBUTES_PROVIDER: StringName = &"attributes.provider"
const EFFECTS_RECEIVER: StringName = &"effects.receiver"
const ABILITIES_OWNER: StringName = &"abilities.owner"
const CONTROL_ENDPOINT: StringName = &"control.endpoint"
const MOVEMENT_MOTOR: StringName = &"movement.motor"
const DAMAGE_RECEIVER: StringName = &"damage.receiver"
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
    EFFECTS_RECEIVER,
    ABILITIES_OWNER,
    CONTROL_ENDPOINT,
    MOVEMENT_MOTOR,
    DAMAGE_RECEIVER,
    INTERACTION_TARGET,
    INVENTORY_OWNER,
    TEST_COUNTER,
    TEST_CHAIN,
    TEST_MULTI,
]

# ====== PUBLIC ========
static func is_known(capability_id: StringName) -> bool:
    return capability_id in ALL
