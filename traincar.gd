extends Node2D

class_name TraincarBase

# The car's position in the train
var sequence : int = 0

var length : int = 200
var height : int = 80
var separation : int = 5

# helper variable to hold the current luxury level of the car
var luxury : float = 0.0

# List of modules in the car
var modules = [null, null, null, null]

func ready():
	position.x = sequence * (length + separation)
	$Outline.transform.size.x = length
	$Outline.transform.size.y = height
	
	for i in range(4):
		add_module("empty", i)

func resource_tick():
	for module in modules:
		module.resource_tick()

func add_module(type : String, position : int):
	#Todo: Instance a new Module scene
	var newModule = ModuleBase.new()
	
	newModule.set_type(type)
	newModule.sequence = position
	
	if modules[position] != null:
		remove_module(position)
	modules[position] = newModule
	add_child(newModule)

func remove_module(position: int):
	var mod_to_remove = modules[position]
	mod_to_remove.cleanup()
	mod_to_remove.queue_free()
