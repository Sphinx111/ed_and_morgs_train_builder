extends RefCounted

class_name ModuleCapabilityRegistry

const CAPABILITIES: Dictionary = {
	"expedition_room": {
		"feature": TrainCapability.FEATURE_MAX_EXPEDITIONS,
		"amount": 1,
	},
}


static func get_config(module_type: String) -> Dictionary:
	return CAPABILITIES.get(module_type, {})


static func has_capability(module_type: String) -> bool:
	return CAPABILITIES.has(module_type)
