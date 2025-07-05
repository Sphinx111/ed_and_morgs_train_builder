extends Node2D

class_name TraincarBase

# The car's position in the train
var sequence : int = 0

# helper variable to hold the current luxury level of the car
var luxury : float = 0.0

# List of modules in the car
var modules = [null, null, null, null]
var ModuleScene = preload("res://Scenes/module.tscn")

func _ready():
	position.x = sequence * (Globals.car_length + Globals.car_separation)
	$Outline.size.x = Globals.car_length
	$Outline.size.y = Globals.car_height
	
	for i in range(4):
		init_module("empty", i)

func set_sequence(newSequence : int):
	sequence = newSequence
	position.x = sequence * (Globals.car_length + Globals.car_separation)

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
		newModule.customers 
		remove_module(position)
	modules[position] = newModule

func add_module(type : String, position : int):
	modules[position].set_type(type)

func remove_module(position: int):
	modules[position].set_type("empty")

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
