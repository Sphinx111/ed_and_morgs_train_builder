extends Resource

## This class holds the data that will populate a Narrative event's Dialog Popup
class_name NarrativeEvent

var id : int = 1
var eventName : String = "exampleEvent2"

var stepsCount : int
var choicesCount : int

const TEXT_ONLY : int = 0
const CHOICE : int = 1
const OUTCOME : int = 2

const DICT_BUTTONTEXT : int = 0
const DICT_OUTCOMETEXT : int = 1
const DICT_EVENTRESULT : int = 2

var sequence : Array[int] 
var promptTexts : Array[String] 
## Structure: key = int. Value = Array of "Button text, Result Text, Emitted Event"
var choicesDict : Dictionary 

func _init(eventKey : String) -> void:
	if eventKey == "treeGuy":
		stepsCount = 2
		choicesCount = 2
		sequence = [TEXT_ONLY, CHOICE, OUTCOME]
		promptTexts = ["You see a survivor hanging from a tree, they are going to try and leap onto your train",
						"Will you open a door to let them in?"]
		choicesDict = {
			0 : ["Yes", "A new passenger joins the train", TrainEvent.new(TrainEvent.CHANGE_RESOURCE, "pop", 1.01)],
			1 : ["No", "You see them fall, they probably didn't survive that", TrainEvent.new(TrainEvent.NO_EFFECT)]
		}
	if eventKey == "startingOut":
		stepsCount = 1
		choicesCount = 3
		sequence = [CHOICE, OUTCOME]
		promptTexts = ["You are away, your home behind you. How do you feel?"]
		choicesDict = {
			0 : ["Relieved - We survived, that's the best we could expect", "Your crew are unaffected",TrainEvent.new(TrainEvent.NO_EFFECT)],
			1 : ["Fearful - How are we supposed to survive this?","Your crew are hardened",TrainEvent.new(TrainEvent.CHANGE_MOOD, -1.0)],
			2 : ["Optimistic - This will be a new start for us","Your crew are happier",TrainEvent.new(TrainEvent.CHANGE_MOOD, 1.0)]
		}
