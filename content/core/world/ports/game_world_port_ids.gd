extends RefCounted
class_name GameWorldPortIds

const OBJECT_RESOLVE: StringName = &"object.resolve"
const OBJECT_REGISTER: StringName = &"object.register"
const SPAWN_REQUEST: StringName = &"spawn.request"
const DESPAWN_REQUEST: StringName = &"despawn.request"
const TARGETING_QUERY: StringName = &"targeting.query"
const TIME_SIMULATION: StringName = &"time.simulation"
const PERSISTENCE_REGISTER: StringName = &"persistence.register"
const STREAMING_REGION: StringName = &"streaming.region"
const ALL: Array[StringName] = [OBJECT_RESOLVE, OBJECT_REGISTER, SPAWN_REQUEST, DESPAWN_REQUEST, TARGETING_QUERY, TIME_SIMULATION, PERSISTENCE_REGISTER, STREAMING_REGION]

static func is_known(port_id: StringName) -> bool:
	return port_id in ALL
