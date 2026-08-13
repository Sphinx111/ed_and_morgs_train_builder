extends Node

## This class holds the data that will populate a Narrative event's Dialog Popup
class_name NarrativeEvent

var eventName : String = "exampleEvent"

var stepsCount : int = 1
var choicesCount : int = 3
var position : int = 0

const TEXT_ONLY : int = 0
const CHOICE : int = 1
const OUTCOME : int = 2

var sequence : Array[int] = [CHOICE, OUTCOME]
var promptTexts : Array[String] = ["You are away, your home behind you. How do you feel?"]
var choiceTexts: Array[String] = ["Relieved - We survived, that's the best we could expect",
								  "Fearful - How are we supposed to survive this?",
								  "Optimistic - This will be a new start for us"]
var narrativeResults : Array[TrainEvent] = [TrainEvent.new(TrainEvent.NO_EFFECT),
						 TrainEvent.new(TrainEvent.CHANGE_MOOD, -1.0),
						 TrainEvent.new(TrainEvent.CHANGE_MOOD, 1.0)]
var outcomeTexts : Array[String] = ["Your crew are unaffected",
								  "Your crew are hardened",
								  "Your crew are happier"]

func _init(eventType : String) -> void:
	pass
