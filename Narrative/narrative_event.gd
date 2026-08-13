extends Resource

## This class holds the data that will populate a Narrative event's Dialog Popup
class_name NarrativeEvent

var id: int = 0
var eventName: String = ""

@export var stepsCount: int
@export var choicesCount: int

const TEXT_ONLY: int = 0
const CHOICE: int = 1
const OUTCOME: int = 2

const DICT_BUTTONTEXT: int = 0
const DICT_OUTCOMETEXT: int = 1
const DICT_EVENTRESULT: int = 2
const DICT_NEXTEVENTKEY: int = 3
const DICT_MIN_DELAY: int = 4

@export var sequence: Array[int]
@export var promptTexts: Array[String]
## Choice row: button text, outcome text, TrainEvent, optional next event key, minimum delay in seconds
@export var choicesDict: Dictionary
