extends Panel

class_name ConstructionPanel

signal placement_requested(module_type: String)
signal addon_placement_requested(addon_type: String)

## Module types that show in the "services" row of the construction menu.
## Everything else buildable falls into the "industry" row.
const SERVICE_MODULE_TYPES: Array[String] = ["cabin", "kitchen", "lounge", "nursery", "expedition_room"]

@onready var _service_row: HBoxContainer = $ModuleButtons/ServiceRow
@onready var _industry_row: HBoxContainer = $ModuleButtons/IndustryRow
@onready var _addon_row: HBoxContainer = $ModuleButtons/AddonRow

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
		var target_row := _service_row if SERVICE_MODULE_TYPES.has(module_type) else _industry_row
		target_row.add_child(new_button)
		_buttons.append(new_button)
		new_button.pressed.connect(_on_module_button_pressed.bind(module_type))
	for addon_type in _get_buildable_addon_types():
		var new_button := Button.new()
		new_button.text = _get_addon_display_label(addon_type)
		new_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		new_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_addon_row.add_child(new_button)
		_buttons.append(new_button)
		new_button.pressed.connect(_on_addon_button_pressed.bind(addon_type))


func teardown() -> void:
	for button in _buttons:
		button.queue_free()
	_buttons.clear()


func _on_module_button_pressed(module_type: String) -> void:
	placement_requested.emit(module_type)


func _on_addon_button_pressed(addon_type: String) -> void:
	addon_placement_requested.emit(addon_type)


func _get_buildable_module_types() -> Array[String]:
	return ModuleDefinitionRegistry.get_buildable_module_types()


func _get_display_label(module_type: String) -> String:
	return ModuleDefinitionRegistry.get_display_label(module_type)


func _get_buildable_addon_types() -> Array[String]:
	return TraincarAddonDefinitionRegistry.get_buildable_addon_types()


func _get_addon_display_label(addon_type: String) -> String:
	return TraincarAddonDefinitionRegistry.get_display_label(addon_type)
