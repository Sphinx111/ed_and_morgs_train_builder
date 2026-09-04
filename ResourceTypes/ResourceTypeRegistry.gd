extends RefCounted

class_name ResourceTypeRegistry

const TYPE_CLEAN_WATER: ResourceType = preload("res://ResourceTypes/clean_water.tres")
const TYPE_GREY_WATER: ResourceType = preload("res://ResourceTypes/grey_water.tres")
const TYPE_BLACK_WATER: ResourceType = preload("res://ResourceTypes/black_water.tres")
const TYPE_FOOD1: ResourceType = preload("res://ResourceTypes/food1.tres")
const TYPE_FOOD2: ResourceType = preload("res://ResourceTypes/food2.tres")
const TYPE_SCRAP: ResourceType = preload("res://ResourceTypes/scrap.tres")
const TYPE_MECH_PARTS: ResourceType = preload("res://ResourceTypes/mech_parts.tres")
const TYPE_OIL: ResourceType = preload("res://ResourceTypes/oil.tres")
const TYPE_FUEL: ResourceType = preload("res://ResourceTypes/fuel.tres")
const TYPE_POP: ResourceType = preload("res://ResourceTypes/pop.tres")
const TYPE_UNKNOWN: ResourceType = preload("res://ResourceTypes/unknown.tres")
const TYPE_TRAIN_CARS: ResourceType = preload("res://ResourceTypes/train_cars.tres")

const TYPES_BY_NAME: Dictionary[String, ResourceType] = {
	"clean_water": TYPE_CLEAN_WATER,
	"grey_water": TYPE_GREY_WATER,
	"black_water": TYPE_BLACK_WATER,
	"food1": TYPE_FOOD1,
	"food2": TYPE_FOOD2,
	"scrap": TYPE_SCRAP,
	"mech_parts": TYPE_MECH_PARTS,
	"oil": TYPE_OIL,
	"fuel": TYPE_FUEL,
	"pop": TYPE_POP,
	"unknown": TYPE_UNKNOWN,
	"trainCars": TYPE_TRAIN_CARS,
}


static func get_type(type_name: String) -> ResourceType:
	return TYPES_BY_NAME.get(type_name)


static func format_amount(type_name: String, amount: float) -> String:
	var resource_type := get_type(type_name)
	if resource_type.is_integer:
		return "%d" % int(amount)
	return Helpers.pretty_print_float(amount)
