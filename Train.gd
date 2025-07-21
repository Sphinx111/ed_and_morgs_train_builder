extends Node2D

class_name Train

var train_name : String = ""	#Give it a name?
var engine : ModuleBase = null
var players = []				#Which players run the train?
var carriages = []
var tickCount = 0 				#Resource ticks since the train launched

var CarriageScene = preload("res://Scenes/traincar_base.tscn")

# Pointer to world map so train can track its position in the world
var worldMap : MapHandler = null

var expedition_safety_flag : bool = false    ## Prevent train leaving if expeditions have been started

# Passenger Navigation Variables
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

var max_res : Dictionary = {}

var speed : float = 200.0
var target_speed : float = 200.00
var acceleration_per_tick : float = 10.0

func _ready() -> void:
	self.position.x = Globals.train_origin_x
	setup_engine()
	passengerManager = find_child("PassengersManager")
	passengerManager.position.x -= Globals.car_length + Globals.car_separation
	
	if Globals.train_direction < 0:
		maxXpos = (Globals.train_initial_carriage_count * (Globals.car_length + Globals.car_separation)) - Globals.car_separation
		minXpos = 0
	else:
		#position.x = Globals.train_origin_x
		maxXpos = 0
		minXpos = -1 * ((Globals.train_initial_carriage_count * (Globals.car_length + Globals.car_separation)) - Globals.car_separation)
	
	init_passenger_map()
	for i in range(0,Globals.train_initial_carriage_count):
		add_carriage(i)
	rebuild_passenger_map()
	worldMap = get_parent().find_child("BasicUI").worldMap

## Set up engine variables, placeholder for now
func setup_engine():
	engine = ModuleBase.new()
	var engineStorage = EngineStorageProvider.new()
	engineStorage.create_storage(self)
	engine.storages.append(engineStorage)

func get_res(key : String) -> float:
	if res.has(key):
		return res.get(key)
	if key == "pop":
		return passengerManager.passengers.size()
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
		if res[key] > max_res[key]:
			res[key] = max_res[key]    ## For now, just discard any excess resources produced
	elif key == "pop":
		for i in range(floor(amount)):
			passengerManager.add_passenger()
	else:
		print_debug("adding resource that doesn't exist: " + key)

func get_expedition_team(passengers_needed : int) -> Array[Passenger]:
	return passengerManager.get_expedition_passengers(passengers_needed)

func recover_expedition(teamArray : Array[Passenger]):
	passengerManager.recover_expedition(teamArray)

func amend_storage(type : String, amount : float):
	if max_res.has(type):
		max_res[type] = max_res[type] + amount
	else:
		max_res[type] = amount

func resource_tick():
	for carriage in carriages:
		if carriage != null:
			carriage.resource_tick()
	passengerManager.resource_tick()
	update_speed()
	worldMap.is_train_in_sun()

func update_speed():
	if expedition_safety_flag == false:
		if target_speed > speed:
			speed = move_toward(speed,target_speed,acceleration_per_tick)
		elif target_speed < speed:
			speed = move_toward(speed,target_speed,acceleration_per_tick*5)

func add_module(type: String, carNum : int, slot : int):
	if carNum >= carriages.size() or slot >= Globals.modules_per_car or carriages[carNum] == null:
		print_debug("Error: Invalid Build slot: " + String.num_int64(carNum) + ":" + String.num_int64(slot))
		return
	
	if type != "empty":
		var cost : float = ModuleBase.build_cost[type]
		if gather_res("mech_parts", cost) == Globals.NO_RESOURCES:
			return
	
	var typesToRemove : Array[String] = carriages[carNum].modules[slot].serves_needs.duplicate()
	carriages[carNum].add_module(type, slot)
	
	update_needs_maps(carriages[carNum].modules[slot].serves_needs,[carNum, slot],Globals.MODULE_ADDED)
	update_needs_maps(typesToRemove,[carNum, slot],Globals.MODULE_REMOVED)

## Add a new car to the end of the train
func add_car():
	add_carriage(carriages.size())
	passengerMap.resize_maps(1)
	if Globals.train_direction > 0:
		minXpos -= Globals.car_length + Globals.car_separation
	elif Globals.train_direction < 0:
		maxXpos += Globals.car_length + Globals.car_separation

func remove_module(carNum : int, slot : int):
	if carriages.size() <= slot or carriages[carNum] == null:
		print_debug("Error: attempting to remove module from nonexistent car: " + String.num_int64(carNum))
	var typesToRemove : Array[String] = carriages[carNum].modules[slot].serves_needs.duplicate()
	var workTypesToRemove : Array[String] = [] 
	if carriages[carNum].modules[slot].workers_needed > 0:
		carriages[carNum].modules[slot].work_types.duplicate()
	var modType = carriages[carNum].modules[slot].type
	var refund : float = ModuleBase.build_cost[modType] * Globals.refund_module_fraction
	add_res("mech_parts", refund)
	
	carriages[carNum].remove_module(slot)

	update_needs_maps(typesToRemove,[carNum, slot],Globals.MODULE_REMOVED)
	if workTypesToRemove.size() > 0:
		update_work_maps(workTypesToRemove,[carNum, slot],Globals.MODULE_REMOVED)

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

func rebuild_passenger_map():
	passengerMap.rebuild_maps()

func update_needs_maps(needsArray : Array[String], position : Array[int], newState : int):
	passengerMap.modify_several_needs_maps(needsArray, position, newState)

func update_work_maps(workArray : Array[String], position : Array[int], newState : int):
	passengerMap.modify_several_work_maps(workArray, position, newState)

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

func _on_speed_lever_changed(new_position: int) -> void:
	target_speed = 100.0 * new_position
	pass # Replace with function body.

func receive_expeditions_started_signal():
	expedition_safety_flag = true

func receive_expeditions_finished_signal():
	expedition_safety_flag = false
	pass
