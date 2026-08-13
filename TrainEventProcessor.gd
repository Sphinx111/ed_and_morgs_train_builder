extends Node

## This class consumes the TrainEvent class, and translates the event into in-game actions
class_name TrainEventProcessor

var train : Train

func _init(myTrain : Train) -> void:
	train = myTrain

func handle_event(newEvent : TrainEvent):
	if newEvent.eventType == TrainEvent.NO_EFFECT:
		return
	if newEvent.eventType == TrainEvent.CHANGE_MOOD:
		if (newEvent.variable1 is float):
			print("Changing mood by %d" % newEvent.variable1)
	if newEvent.eventType == TrainEvent.CHANGE_RESOURCE:
		if (newEvent.variable1 is String && newEvent.variable2 is float):
			train.add_res(newEvent.variable1, newEvent.variable2)
