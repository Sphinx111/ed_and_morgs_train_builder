extends Node2D

class_name TraincarBase

# The car's position in the train
var sequence : int = 0
var parentTrain : Train = null

# helper variable to hold the current luxury level of the car
var luxury : float = 0.0

# List of modules in the car
var modules = [null, null, null, null]
var ModuleScene = preload("res://Scenes/module.tscn")
var defaultModuleArray = ["clean_water", "farm", "cabin", "passenger_door"]

func _ready():
	if Globals.train_direction < 0:
		position.x = sequence * (Globals.car_length + Globals.car_separation)
	else:
		# Pos      = Train origin           - Leftwards for each car in sequence                         - extra because drawing is from the left
		position.x = 0 - ((sequence + 1) * (Globals.car_length + Globals.car_separation)) - Globals.car_length
	$Outline.size.x = Globals.car_length
	$Outline.size.y = Globals.car_height
	parentTrain = get_parent()
	
	for i in range(4):
		init_module("empty", i)

func set_sequence(newSequence : int):
	sequence = newSequence
	if Globals.train_direction < 0:
		position.x = sequence * (Globals.car_length + Globals.car_separation)
	else: 
		position.x = 0 - ((sequence + 1) * (Globals.car_length + Globals.car_separation)) - Globals.car_length
		
	if newSequence== 0:
		for i in range(4):
			init_module(defaultModuleArray[i], i)
func resource_tick():
	for module in modules:
		if module != null:
			module.resource_tick()

func init_module(type : String, position : int):
	#Todo: Instance a new Module scene
	var newModule = ModuleScene.instantiate()
	self.add_child(newModule)
	
	newModule.set_type(type)
	newModule.set_sequence(position)
	
	if modules[position] != null:
		newModule.customers  = modules[position].customers
		newModule.workers  = modules[position].workers
		remove_module(position)
	modules[position] = newModule

func add_module(type : String, slot : int):
	modules[slot].set_type(type)

func remove_module(slot: int):
	modules[slot].set_type("empty")

func get_type_map(need_type_to_find : String) -> Array:
	var result = [0,0,0,0]
	for i in range(4):
		if modules[i].can_serve_need(need_type_to_find):
			result[i] = 1
	return result

func get_work_map(work_type_to_find : String) -> Array:
	var result = [0,0,0,0]
	for i in range(4):
		if modules[i].needs_worker(work_type_to_find):
			result[i] = 1
	return result

func update_needs_maps(needsArray : Array[String], modulePos : int, newState : int):
	parentTrain.update_needs_maps(needsArray, [sequence, modulePos], newState)

func update_work_maps(workArray : Array[String], modulePos : int, newState : int):
	parentTrain.update_work_maps(workArray, [sequence, modulePos], newState)
