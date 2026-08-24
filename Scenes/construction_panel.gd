extends Panel

class_name ConstructionPanel

signal placement_requested(module_type: String)

const MODULE_DISPLAY_LABELS: Dictionary[String, String] = {
	"clean_water": "Water",
	"mech_parts": "Parts",
	"farm": "Farm",
	"scrap_arm": "Scrap",
	"kitchen": "Kitchen",
	"cabin": "Cabin",
	"expedition_room": "Expedition Room",
	"water_collector": "H2O Scoop",
	"fuel_refinery": "Refinery",
}

@onready var _module_buttons: HBoxContainer = $ModuleButtons

var _buttons: Array[Button] = []


func _ready() -> void:
	apply_panel_layout()


func apply_panel_layout() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = Globals.construction_panel_width_percent / 100.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = Globals.resource_panel_height
	offset_right = 0.0
	offset_bottom = Globals.resource_panel_height + Globals.construction_panel_height


func setup() -> void:
	teardown()
	for module_type in _get_buildable_module_types():
		var new_button := Button.new()
		new_button.text = _get_display_label(module_type)
		new_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		new_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_module_buttons.add_child(new_button)
		_buttons.append(new_button)
		new_button.pressed.connect(_on_module_button_pressed.bind(module_type))


func teardown() -> void:
	for button in _buttons:
		button.queue_free()
	_buttons.clear()


func _on_module_button_pressed(module_type: String) -> void:
	placement_requested.emit(module_type)


func _get_buildable_module_types() -> Array[String]:
	var module_types: Array[String] = []
	for module_type in ModuleBase.build_cost.keys():
		module_types.append(module_type)
	module_types.sort()
	return module_types


func _get_display_label(module_type: String) -> String:
	if MODULE_DISPLAY_LABELS.has(module_type):
		return MODULE_DISPLAY_LABELS[module_type]
	return module_type.replace("_", " ")
