extends Node

## This class consumes the TrainEvent class, and translates the event into in-game actions
class_name TrainEventProcessor

var train : Train

func _init(myTrain : Train) -> void:
	train = myTrain

func handle_event(newEvent : TrainEvent) -> void:
	if newEvent.eventType == TrainEvent.NO_EFFECT:
		return
	if newEvent.eventType == TrainEvent.CHANGE_MOOD:
		if newEvent.variable1 is float:
			print("Changing mood by %d" % newEvent.variable1)
	if newEvent.eventType == TrainEvent.CHANGE_POP:
		if newEvent.variable1 is int:
			print("eventProcessor:: CHANGE_POP by %d" % newEvent.variable1)
			train.add_pop(newEvent.variable1)
	if newEvent.eventType == TrainEvent.CHANGE_RESOURCE:
		if newEvent.variable1 is String and newEvent.variable2 is float:
			print("eventProcessor:: resType=%s resAmt=%f" % [newEvent.variable1, newEvent.variable2])
			train.add_res(newEvent.variable1, newEvent.variable2)
