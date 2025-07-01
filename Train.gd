extends Node2D

class_name Train

var train_name : String = ""	#Give it a name?
var players = []				#Which players run the train?
var carriages = []
var tickCount = 0 				#Resource ticks since the train launched

var CarriageScene = preload("res://Scenes/traincar_base.tscn")

var passengerMap : PassengerMap = null
var passengerManager : PassengerManager = null

var minXpos : float = 0.0
var maxXpos : float = 0.0

# x varieties of food
var res = {
	"food1" : 100.0,
	"food2" : 100.0,
	"food3" : 0.0,
	"food4" : 0.0,
	"food5" : 0.0,
	"food6" : 0.0,
	"clean_water" : 100.0,
	"grey_water" : 0.0,
	"black_water" : 0.0,
	"mech_parts" : 100.0,
	"speed" : 50.0,
	"fuel" : 100.0,
	"fertiliser" : 10.0,
	"seeds1" : 10.0,
	"seeds2" : 10.0,
	"seeds3" : 0.0,
	"seeds4" : 0.0,
	"seeds5" : 0.0,
	"seeds6" : 0.0
}

func _ready() -> void:
	for i in range(0,3):
		add_carriage(i)
	maxXpos = (carriages.size() * (Globals.car_length + Globals.car_separation)) - Globals.car_separation
	passengerManager = find_child("PassengersManager")
	init_passenger_map()

func get_res(key : String) -> float:
	if res.has(key):
		return res.get(key)
	return 0

func add_res(key : String, amount : float):
	if res.has(key):
		res[key] = res[key] + amount
	else:
		print_debug("adding resource that doesn't exist: " + key)

func resource_tick():
	for carriage in carriages:
		if carriage != null:
			carriage.resource_tick()
	passengerManager.resource_tick()

func add_module(type: String, carNum : int, position : int):
	if carriages.size() <= position or carriages[carNum] == null:
		print_debug("Error: attempting to add module to nonexistent car: " + String.num_int64(carNum))
	remove_module(carNum, position)
	
	carriages[carNum].add_module(type, position)
	for needType in carriages[carNum].modules[position].serves_needs:
		passengerMap.update_single_type_map(needType)                         # Update the passenger nav map for this type

func remove_module(carNum : int, position : int):
	if carriages.size() <= position or carriages[carNum] == null:
		print_debug("Error: attempting to remove module from nonexistent car: " + String.num_int64(carNum))
	var typesToRemove : Array[String] = carriages[carNum].modules[position].serves_needs.duplicate()
	carriages[carNum].remove_module(position)
	for needsType in typesToRemove:
		passengerMap.update_single_type_map(needsType)                         # Update the passenger nav map for this type

func add_carriage(sequence : int):
	var newCarriage = CarriageScene.instantiate()
	add_child(newCarriage)
	carriages.append(newCarriage)
	newCarriage.set_sequence(sequence)

func add_passenger_debug():
	passengerManager.add_passenger()

func get_car_count():
	return carriages.size()

func init_passenger_map():
	passengerMap = PassengerMap.new()
	passengerMap.set_train(self)
	passengerMap.init_maps()

# Return a simple array of where each type of need can be met for passengers
func get_location_map_for_type(need_type_to_find : String) -> Array:
	var result = []
	
	for i in range(carriages.size()):
		result.append(carriages[i].get_type_map(need_type_to_find))
	
	return result

func get_trainpos_from_coords(localPos : Vector2) -> Array[int]:
	var carIndex : int = floor(localPos.x / (Globals.car_length + Globals.car_separation) )
	var posInCar : int = (localPos.x - carriages[carIndex].position.x)
	var moduleIndex : int = floor(min((posInCar / Globals.module_width), (Globals.modules_per_car - 1)))
	return [carIndex,moduleIndex]

func get_xpos_from_trainpos(trainPos: Array) -> float:
	var result : float = (trainPos[0] * (Globals.car_length + Globals.car_separation))
	result = result + (trainPos[1] * Globals.module_width)
	return result
