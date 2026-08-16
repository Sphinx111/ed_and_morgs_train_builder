extends Node

## Container Class to contain data of a single resource type at a MapLocation
class_name MapResourceContainer

@export var resource_type : String
@export var amount : float
@export var travel_time : float

func _init(_resource_type : String = "", _amount : float = 0.0, _travel_time : float = 0.0):
	resource_type = _resource_type
	amount = _amount
	travel_time = _travel_time

func is_empty() -> bool:
	if amount <= 0.0:
		return true
	return false


func get_debug_text() -> String:
	return "%s: %s" % [resource_type, Helpers.pretty_print_float(amount)]

func _take_resource(_amount : float) -> float:
	var to_remove : float = min(_amount, amount)
	amount = amount - to_remove
	return to_remove
