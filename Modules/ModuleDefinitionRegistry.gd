extends RefCounted

class_name ModuleDefinitionRegistry

const DEFINITIONS: Dictionary = {
	"water_purifier": {
		"outline_color": Color.AQUA,
		"workers": 1,
		"storage": {"clean_water": 50.0, "grey_water": 50.0},
		"build_cost": 25.0,
		"display_label": "Water Purifier",
	},
	"sewage_works": {
		"outline_color": Color.SLATE_GRAY,
		"workers": 1,
		"storage": {"grey_water": 50.0, "black_water": 10.0},
		"build_cost": 25.0,
		"display_label": "Sewage Works",
	},
	"cabin": {
		"outline_color": Color.BROWN,
		"base_customers": 4,
		"build_cost": 2.0,
		"display_label": "Cabin",
	},
	"kitchen": {
		"outline_color": Color.BISQUE,
		"base_customers": 4,
		"storage": {"clean_water": 20.0, "food1": 10.0, "food2": 10.0},
		"build_cost": 5.0,
		"display_label": "Kitchen",
	},
	"farm": {
		"outline_color": Color.SEA_GREEN,
		"workers": 5,
		"base_customers": 5,
		"storage": {"food1": 50.0, "food2": 50.0},
		"build_cost": 10.0,
		"display_label": "Farm",
	},
	"scrap_arm": {
		"outline_color": Color.SANDY_BROWN,
		"workers": 1,
		"storage": {"scrap": 50.0},
		"build_cost": 50.0,
		"display_label": "Scrap",
	},
	"mech_parts": {
		"outline_color": Color.SANDY_BROWN,
		"workers": 1,
		"storage": {"mech_parts": 50.0},
		"build_cost": 20.0,
		"display_label": "Parts",
	},
	"expedition_room": {
		"outline_color": Color.MEDIUM_PURPLE,
		"build_cost": 20.0,
		"display_label": "Expedition Room",
	},
	"water_collector": {
		"outline_color": Color.CADET_BLUE,
		"workers": 1,
		"storage": {"grey_water": 100.0},
		"build_cost": 25.0,
		"display_label": "H2O Scoop",
	},
	"fuel_refinery": {
		"outline_color": Color.DARK_SLATE_GRAY,
		"workers": 8,
		"storage": {"oil": 100.0, "fuel": 100.0},
		"build_cost": 50.0,
		"display_label": "Refinery",
	},
	"lounge": {
		"outline_color": Color.CORNFLOWER_BLUE,
		"base_customers": 8,
		"min_customers_for_service": 2,
		"build_cost": 10.0,
		"display_label": "Lounge",
	},
}


static func get_definition(module_type: String) -> Dictionary:
	return DEFINITIONS.get(module_type, {})


static func has_definition(module_type: String) -> bool:
	return DEFINITIONS.has(module_type)


static func get_build_cost(module_type: String) -> float:
	return DEFINITIONS.get(module_type, {}).get("build_cost", 0.0)


static func get_buildable_module_types() -> Array[String]:
	var module_types: Array[String] = []
	for module_type in DEFINITIONS.keys():
		module_types.append(module_type)
	module_types.sort()
	return module_types


static func get_display_label(module_type: String) -> String:
	var config := get_definition(module_type)
	if config.has("display_label"):
		return config.display_label
	return module_type.replace("_", " ")
