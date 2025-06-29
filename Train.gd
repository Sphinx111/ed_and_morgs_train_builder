extends Node2D

class_name Train

var train_name : String = ""	#Give it a name?
var players = []				#Which players run the train?
var carriages = []
var tickCount = 0 				#Resource ticks since the train launched

var CarriageScene = preload("res://Scenes/traincar_base.tscn")

var passengerMap : PassengerMap = null

# x varieties of food
var res = {
	"food1" : 100,
	"food2" : 100,
	"food3" : 0,
	"food4" : 0,
	"food5" : 0,
	"food6" : 0,
	"clean_water" : 100,
	"grey_water" : 0,
	"black_water" : 0,
	"mech_parts" : 0,
	"speed" : 50,
	"fuel" : 100,
	"fertiliser" : 20,
	"seeds1" : 10,
	"seeds2" : 10,
	"seeds3" : 10,
	"seeds4" : 10,
	"seeds5" : 10,
	"seeds6" : 10
}

func _ready() -> void:
	for i in range(0,3):
		add_carriage(i)
	init_passenger_map()

func get_res(key : String) -> int:
	if res.has(key):
		return res.get(key)
	return 0

func add_res(key : String, amount : int):
	if res.has(key):
		res[key] = res[key] + amount
	else:
		print_debug("adding resource that doesn't exist: " + key)

func resource_tick():
	for carriage in carriages:
		if carriage != null:
			carriage.resource_tick()

func add_module(type: String, carNum : int, position : int):
	if carriages.size() <= position or carriages[carNum] == null:
		print_debug("Error: attempting to add module to nonexistent car: " + String.num_int64(carNum))
	carriages[carNum].add_module(type, position)
	passengerMap.update_single_type_map(type)                         # Update the passenger nav map for this type

func remove_module(carNum : int, position : int):
	if carriages.size() <= position or carriages[carNum] == null:
		print_debug("Error: attempting to remove module from nonexistent car: " + String.num_int64(carNum))
	var typeToRemove : String = carriages[carNum].modules[position].type
	carriages[carNum].remove_module(position)
	passengerMap.update_single_type_map(typeToRemove)                         # Update the passenger nav map for this type

func add_carriage(sequence : int):
	var newCarriage = CarriageScene.instantiate()
	add_child(newCarriage)
	carriages.append(newCarriage)
	newCarriage.set_sequence(sequence)

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
	var carIndex = floor(localPos.x / Globals.car_length + Globals.car_separation)
	var posInCar = localPos.x - carriages[carIndex].position.x
	var moduleIndex = floor(posInCar / Globals.module_width)
	return [carIndex,moduleIndex]
	pass
