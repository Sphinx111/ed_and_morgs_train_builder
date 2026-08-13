extends Node

## This class is a data container which is typically emitted by a signal
## It holds a type of event, and any variables used in that event
class_name TrainEvent

## These are effectively enums for the class, to define the type of event
const NO_EFFECT : int = 0
const CHANGE_RESOURCE : int = 1
const CHANGE_MOOD : int = 2
const CHANGE_POP : int = 3

var eventType : int = 0

var variable1 # untyped variable, flexible depending on event type
var variable2 # untyped variable, flexible depending on event type


func _init(type: int = NO_EFFECT, var1: Variant = null, var2: Variant = null) -> void:
	eventType = type
	variable1 = var1
	variable2 = var2
