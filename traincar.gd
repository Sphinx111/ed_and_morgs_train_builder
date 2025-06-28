extends Node2D

class_name TraincarBase

# The car's position in the train
var sequence : int = 0

# helper variable to hold the current luxury level of the car
var luxury : float = 0.0

# List of modules in the car
var modules = []

func resource_tick():
	for module in modules:
		module.resource_tick()

func add_module(newModule):
	if newModule is ModuleBase:
		newModule.sequence = modules.size()
		newModule.parentCar = self
		modules.append(newModule)

func remove_module():
	var mod_to_remove = modules.pop_back()
	mod_to_remove.cleanup()
	mod_to_remove.queue_free()
