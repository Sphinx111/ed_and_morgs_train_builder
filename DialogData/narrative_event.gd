extends Resource

## This class holds the data that will populate a Narrative event's Dialog Popup
class_name NarrativeEvent

var id : int = 1
var eventName : String = "exampleEvent2"

var stepsCount : int = 2
var choicesCount : int = 2
var position : int = 0

const TEXT_ONLY : int = 0
const CHOICE : int = 1
const OUTCOME : int = 2

const DICT_BUTTONTEXT : int = 0
const DICT_OUTCOMETEXT : int = 1
const DICT_EVENTRESULT : int = 2

var sequence : Array[int] = [TEXT_ONLY, CHOICE, OUTCOME]
var promptTexts : Array[String] = ["You see a survivor hanging from a tree, they are going to try and leap onto your train",
									"Will you open a door to let them in?"]
## Structure: key = int. Value = Array of "Button text, Result Text, Emitted Event"
var choicesDict : Dictionary = {
	0 : ["Yes", "A new passenger joins the train", TrainEvent.new(TrainEvent.CHANGE_RESOURCE, "pop", 1.01)],
	1 : ["No", "You see them fall, they probably didn't survive that", TrainEvent.new(TrainEvent.NO_EFFECT)]
}

func _init(eventKey : String) -> void:
	pass
