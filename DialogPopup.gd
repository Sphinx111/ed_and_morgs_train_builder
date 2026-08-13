extends Control

class_name DialogPopup

@onready var promptLabel: RichTextLabel = get_node("DialogPanel/PromptLabel")
@onready var button1: Button = get_node("DialogPanel/Button1")
@onready var button2: Button = get_node("DialogPanel/Button2")
@onready var button3: Button = get_node("DialogPanel/Button3")

signal event_finished

var choiceMade : int = 0
var stepPos : int = 0
var activeEvent : NarrativeEvent
var ready_to_close : bool = false

func set_event(new_event: NarrativeEvent) -> void:
	activeEvent = new_event
	stepPos = 0
	choiceMade = 0
	ready_to_close = false
	button1.hide()
	button2.hide()
	button3.hide()
	_load_step(stepPos)

func _load_step(stepNum : int) -> void:
	## Protect against outOfBounds exceptions
	if stepNum > activeEvent.stepsCount:
		print_debug("%d stepcount reached???" % stepNum)
		return
	
	## if we are on the final step of event
	if (activeEvent.sequence[stepNum] == NarrativeEvent.OUTCOME):
		promptLabel.text = activeEvent.choicesDict.get(choiceMade)[NarrativeEvent.DICT_OUTCOMETEXT]
		button1.text = "Continue"
		button1.show()
		ready_to_close = true
		return
	## if we are on a TEXT_ONLY step
	elif (activeEvent.sequence[stepNum] == NarrativeEvent.TEXT_ONLY):
		promptLabel.text = activeEvent.promptTexts[stepNum]
		button1.text = "Continue"
		button1.show()
	## if we are on a CHOICE step
	elif (activeEvent.sequence[stepNum] == NarrativeEvent.CHOICE):
		promptLabel.text = activeEvent.promptTexts[stepNum]
		if activeEvent.choicesCount >= 1:
			button1.text = activeEvent.choicesDict.get(0)[NarrativeEvent.DICT_BUTTONTEXT]
			button1.show()
		if activeEvent.choicesCount >= 2:
			button2.text = activeEvent.choicesDict.get(1)[NarrativeEvent.DICT_BUTTONTEXT]
			button2.show()
		if activeEvent.choicesCount >= 3:
			button3.text = activeEvent.choicesDict.get(2)[NarrativeEvent.DICT_BUTTONTEXT]
			button3.show()
	pass

func next_step():
	stepPos += 1
	button1.hide()
	button2.hide()
	button3.hide()
	_load_step(stepPos)

func _on_button1_pressed() -> void:
	if ready_to_close:
		_event_finished()
		return;
	choiceMade = 0
	next_step()


func _on_button2_pressed() -> void:
	choiceMade = 1
	next_step()


func _on_button3_pressed() -> void:
	choiceMade = 2
	next_step()

func _event_finished() -> void:
	var choice_data: Array = activeEvent.choicesDict.get(choiceMade)
	var result: TrainEvent = choice_data[NarrativeEvent.DICT_EVENTRESULT]
	var next_event_key: String = choice_data[NarrativeEvent.DICT_NEXTEVENTKEY] if choice_data.size() > NarrativeEvent.DICT_NEXTEVENTKEY else ""
	var min_delay: float = choice_data[NarrativeEvent.DICT_MIN_DELAY] if choice_data.size() > NarrativeEvent.DICT_MIN_DELAY else 0.0
	print("DialogPopup::_event_finished, choice=%d, eventType=%d, next=%s, delay=%s" % [choiceMade, result.eventType, next_event_key, min_delay])
	event_finished.emit(result, next_event_key, min_delay)
