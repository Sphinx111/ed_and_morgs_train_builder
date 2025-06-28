extends Node2D

class_name ModuleBase

var parentCar : TraincarBase = null
var type : String = "empty"
var efficiency : float = 1.0
var workers_needed : int = 0
var luxury_effect : int = 0

var enabled : bool = true

func resource_tick():
	pass

# Do anything we need before the module gets deleted
func cleanup():
	pass
