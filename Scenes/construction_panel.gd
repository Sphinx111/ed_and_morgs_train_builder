extends Panel

class_name ConstructionPanel

signal placement_requested(module_type: String)

const MODULE_TYPE_ALIASES: Dictionary = {
	"water": "clean_water",
	"food": "farm",
	"kitchen": "kitchen",
	"cabin": "cabin",
}

var buttons: Array[Button] = []


func setup() -> void:
	var button_list: Array[String] = ["water", "food", "kitchen", "cabin"]
	for button_word in button_list:
		var new_button := Button.new()
		new_button.text = button_word
		add_child(new_button)
		buttons.append(new_button)
		new_button.position.x = buttons.size() * 60 + 10
		new_button.pressed.connect(press_button.bind(new_button.text))


func teardown() -> void:
	for i in range(buttons.size() - 1, -1, -1):
		buttons[i].queue_free()
		buttons.remove_at(i)


func press_button(button_text: String) -> void:
	var module_type: String = MODULE_TYPE_ALIASES.get(button_text, button_text)
	placement_requested.emit(module_type)
