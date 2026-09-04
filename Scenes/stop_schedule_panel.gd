extends Panel

class_name StopSchedulePanel

const YARD_LABEL: String = "Yard"

var buttons : Array [Button]
var buttonList : Array [String] = [
	"grey_water",
	"clean_water",
	"oil",
	"pop",
	"scrap",
	"mech_parts",
	"food1",
	MapResourceLocation.RESOURCE_TYPE,
	"unknown",
]
@onready var vBox : VBoxContainer = get_node("VBoxContainer")

func setup() -> void:
	if buttons.size() == 0:
		for resource_type in buttonList:
			_add_resource_button(resource_type)
		var cancel_button : Button = Button.new()
		vBox.add_child(cancel_button)
		cancel_button.text = "Cancel"
		cancel_button.set_meta("resource_type", "")
		cancel_button.pressed.connect(resourceSelectPress.bind(""))
		buttons.append(cancel_button)
	else:
		_ensure_yard_button()
	_refresh_yard_button()

func _add_resource_button(resource_type: String) -> Button:
	var new_button : Button = Button.new()
	vBox.add_child(new_button)
	new_button.set_meta("resource_type", resource_type)
	new_button.text = _button_label_for(resource_type)
	new_button.pressed.connect(resourceSelectPress.bind(resource_type))
	buttons.append(new_button)
	return new_button

func _ensure_yard_button() -> void:
	if _find_button_for_type(MapResourceLocation.RESOURCE_TYPE) != null:
		return
	var cancel_index : int = buttons.size() - 1
	var yard_button : Button = _add_resource_button(MapResourceLocation.RESOURCE_TYPE)
	vBox.move_child(yard_button, cancel_index)

func _refresh_yard_button() -> void:
	var yard_button : Button = _find_button_for_type(MapResourceLocation.RESOURCE_TYPE)
	if yard_button == null:
		return
	var our_map : MapHandler = get_parent().worldMap
	yard_button.visible = our_map.get_distance_to_next_resource(MapResourceLocation.RESOURCE_TYPE) > -9990

func _find_button_for_type(resource_type: String) -> Button:
	for button in buttons:
		if button.get_meta("resource_type", "") == resource_type:
			return button
	return null

func _button_label_for(resource_type: String) -> String:
	if resource_type == MapResourceLocation.RESOURCE_TYPE:
		return YARD_LABEL
	return resource_type

func resourceSelectPress(resource_selection : String) -> void:
	buttonHighlight(resource_selection)
	var our_map : MapHandler = get_parent().worldMap
	our_map.set_schedule_stop(resource_selection)
	var resource_dist : float = our_map.get_distance_to_next_resource(resource_selection)
	if resource_dist > -9990:
		print("Next %s stop is at %f" % [resource_selection, resource_dist])
	else:
		print("No %s stop is available along current route" % resource_selection)

func buttonHighlight(selected_type : String) -> void:
	for button in buttons:
		var button_type : String = button.get_meta("resource_type", button.text)
		if button_type == "":
			button.disabled = false
			continue
		button.disabled = button_type == selected_type

func cleanup_buttons() -> void:
	pass
