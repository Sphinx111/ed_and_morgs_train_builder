extends Control

class_name DialogPopup

@onready var promptLabel: RichTextLabel = get_node("DialogPanel/PromptLabel")
@onready var button1: Button = get_node("DialogPanel/Button1")
@onready var button2: Button = get_node("DialogPanel/Button2")
@onready var button3: Button = get_node("DialogPanel/Button3")

signal option1
signal option2
signal option3
signal finished

var choiceMade : int = 0
var stepPos : int = 0
var activeEvent : NarrativeEvent
var ready_to_close : bool = false

func set_event(new_event: NarrativeEvent) -> void:
	activeEvent = new_event
	_load_step(stepPos)

func _load_step(stepNum : int) -> void:
	if stepNum > activeEvent.stepsCount:
		print_debug("%d stepcount reached???" % stepNum)
		return
	if (activeEvent.sequence[stepNum] == NarrativeEvent.OUTCOME):
		promptLabel.text = activeEvent.outcomeTexts[choiceMade]
		button1.text = "Continue"
		button1.show()
		ready_to_close = true
		return
	elif (activeEvent.sequence[stepNum] == NarrativeEvent.TEXT_ONLY):
		promptLabel.text = activeEvent.promptTexts[stepNum]
		button1.text = "Continue"
		button1.show()
	elif (activeEvent.sequence[stepNum] == NarrativeEvent.CHOICE):
		promptLabel.text = activeEvent.promptTexts[stepNum]
		if activeEvent.choicesCount >= 1:
			button1.text = activeEvent.choiceTexts[0]
			button1.show()
		if activeEvent.choicesCount >= 2:
			button2.text = activeEvent.choiceTexts[1]
			button2.show()
		if activeEvent.choicesCount >= 3:
			button3.text = activeEvent.choiceTexts[2]
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
	pass # Replace with function body.


func _on_button2_pressed() -> void:
	choiceMade = 1
	next_step()
	pass # Replace with function body.


func _on_button3_pressed() -> void:
	choiceMade = 2
	next_step()
	pass # Replace with function body.

func _event_finished() -> void:
	if choiceMade == 0:
		option1.emit()
	elif choiceMade == 1:
		option2.emit()
	elif choiceMade == 2:
		option3.emit()
