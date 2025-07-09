extends Node2D

class_name Train

var train_name : String = ""	#Give it a name?
var players = []				#Which players run the train?
var carriages = []
var tickCount = 0 				#Resource ticks since the train launched

var CarriageScene = preload("res://Scenes/traincar_base.tscn")

var passengerMap : PassengerMap = null
var worldMap : MapHandler = null
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
	"speed" : 500.0,
	"fuel" : 100.0,
	"fertiliser" : 10.0,
	"seeds1" : 10.0,
	"seeds2" : 10.0,
	"seeds3" : 0.0,
	"seeds4" : 0.0,
	"seeds5" : 0.0,
	"seeds6" : 0.0,
	"scrap" : 0.0
}

func _ready() -> void:
	self.position.x = Globals.train_origin_x
	for i in range(0,3):
		add_carriage(i)
	passengerManager = find_child("PassengersManager")
	passengerManager.position.x -= Globals.car_length + Globals.car_separation
	
	if Globals.train_direction < 0:
		maxXpos = (carriages.size() * (Globals.car_length + Globals.car_separation)) - Globals.car_separation
		minXpos = 0
	else:
		#position.x = Globals.train_origin_x
		maxXpos = 0
		minXpos = -1 * ((carriages.size() * (Globals.car_length + Globals.car_separation)) - Globals.car_separation)
	
	init_passenger_map()
	worldMap = get_parent().find_child("BasicUI").worldMap

func get_res(key : String) -> float:
	if res.has(key):
		return res.get(key)
	return 0

## Function to consume amount if available, returns a status code
func gather_res(key : String, amount : float) -> int:
	if res.has(key) and res[key] >= amount:
		add_res(key, -amount)
		return Globals.RESULT_OK
	return Globals.NO_RESOURCES

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
	if carNum >= carriages.size() or position >= Globals.modules_per_car or carriages[carNum] == null:
		print_debug("Error: Invalid Build position: " + String.num_int64(carNum) + ":" + String.num_int64(position))
		return
	
	if type != "empty":
		var cost : float = ModuleBase.build_cost[type]
		if gather_res("mech_parts", cost) == Globals.NO_RESOURCES:
			return
	
	var typesToRemove : Array[String] = carriages[carNum].modules[position].serves_needs.duplicate()
	carriages[carNum].add_module(type, position)
	
	update_needs_maps(carriages[carNum].modules[position].serves_needs,[carNum, position],Globals.MODULE_ADDED)
	update_needs_maps(typesToRemove,[carNum, position],Globals.MODULE_REMOVED)
	
	passengerMap.update_single_work_type_map("any")

func remove_module(carNum : int, position : int):
	if carriages.size() <= position or carriages[carNum] == null:
		print_debug("Error: attempting to remove module from nonexistent car: " + String.num_int64(carNum))
	var typesToRemove : Array[String] = carriages[carNum].modules[position].serves_needs.duplicate()
	var modType = carriages[carNum].modules[position].type
	var refund : float = ModuleBase.build_cost[modType] * Globals.refund_module_fraction
	add_res("mech_parts", refund)
	
	carriages[carNum].remove_module(position)

	update_needs_maps(typesToRemove,[carNum, position],Globals.MODULE_REMOVED)

	passengerMap.update_single_work_type_map("any")

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

func update_work_map(workType : String):
	passengerMap.update_single_work_type_map("any")
	if workType != "" and workType != "any":
		passengerMap.update_single_work_type_map(workType)

func update_needs_maps(needsArray : Array[String], position : Array[int], newState : int):
	passengerMap.modify_several_needs_maps(needsArray, position, newState)

# Return a simple array of where each type of need can be met for passengers
func get_location_map_for_type(need_type_to_find : String) -> Array:
	var result = []
	
	for i in range(carriages.size()):
		result.append(carriages[i].get_type_map(need_type_to_find))
	
	return result

func get_work_location_map_for_type(work_type_to_find : String) -> Array:
	var result = []
	for i in range(carriages.size()):
		result.append(carriages[i].get_work_map(work_type_to_find))
	
	return result
