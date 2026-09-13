extends RefCounted

class_name TraincarAddonDefinitionRegistry

## Single source of config per addon type: visuals/cost plus whichever effect field(s) it needs.
## TraincarAddonBase dispatches on which of these are present - an addon can combine more than
## one if it ever needs to:
##  - "capability_feature" (String) + "capability_amount" (int): a train-wide TrainCapability
##    effect (Globals mutation), e.g. antenna_count / kite_sail_count.
##  - "car_stats" (Dictionary[String, float]): stat_name -> amount, applied additively onto the
##    specific TraincarBase this addon is mounted on (e.g. heat_resistance, luxury_rating).
##  - "passive_production" (Dictionary): {"resource_type": String, "amount_per_tick": float,
##    "requires_shade": bool} - a per-tick trickle of one resource, optionally only while the
##    train is not in sunlight.
const DEFINITIONS: Dictionary = {
	"radio_antenna": {
		"outline_color": Color.ORANGE,
		"build_cost": 15.0,
		"display_label": "Radio Antenna",
		"capability_feature": TrainCapability.FEATURE_ANTENNA_COUNT,
		"capability_amount": 1,
	},
	"kite_sail": {
		"outline_color": Color.LIGHT_SKY_BLUE,
		"build_cost": 15.0,
		"display_label": "Kite Sail",
		"capability_feature": TrainCapability.FEATURE_KITE_SAIL_COUNT,
		"capability_amount": 1,
	},
	"moisture_collector": {
		"outline_color": Color.CADET_BLUE,
		"build_cost": 15.0,
		"display_label": "Moisture Collector",
		"passive_production": {
			"resource_type": "clean_water",
			"amount_per_tick": 0.05,
			"requires_shade": true,
		},
	},
	"heat_shielding": {
		"outline_color": Color.ORANGE_RED,
		"build_cost": 15.0,
		"display_label": "Heat Shielding",
		"car_stats": {"heat_resistance": 0.3},
	},
}


static func get_definition(addon_type: String) -> Dictionary:
	return DEFINITIONS.get(addon_type, {})


static func has_definition(addon_type: String) -> bool:
	return DEFINITIONS.has(addon_type)


static func get_build_cost(addon_type: String) -> float:
	return DEFINITIONS.get(addon_type, {}).get("build_cost", 0.0)


static func get_buildable_addon_types() -> Array[String]:
	var addon_types: Array[String] = []
	for addon_type in DEFINITIONS.keys():
		addon_types.append(addon_type)
	addon_types.sort()
	return addon_types


static func get_display_label(addon_type: String) -> String:
	var config := get_definition(addon_type)
	if config.has("display_label"):
		return config.display_label
	return addon_type.replace("_", " ")
