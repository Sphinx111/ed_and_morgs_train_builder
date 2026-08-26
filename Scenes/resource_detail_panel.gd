extends Panel

class_name ResourceDetailPanel

const MOTHBALL_BUTTON_NORMAL_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const MOTHBALL_BUTTON_ACTIVE_COLOR := Color(1.0, 0.78, 0.78, 1.0)

@onready var _type_label: Label = get_node("MarginContainer/VBoxContainer/TypeLabel")
@onready var _value_label: Label = get_node("MarginContainer/VBoxContainer/ValueLabel")
@onready var _mothball_button: Button = get_node("MarginContainer/VBoxContainer/Button")

var _train: Train = null
var _resource_type: ResourceType = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mothball_button.toggled.connect(_on_mothball_button_toggled)
	hide()


func show_for_resource(resource_type: ResourceType, train: Train) -> void:
	_train = train
	_resource_type = resource_type
	_type_label.text = resource_type.display_name
	_value_label.text = _format_detail_value(resource_type, train)
	_sync_mothball_button()
	show()


func hide_panel() -> void:
	hide()


func _sync_mothball_button() -> void:
	if _train == null or _resource_type == null:
		return
	var mothballed := _train.is_industry_mothballed(_resource_type.type_name)
	_mothball_button.set_block_signals(true)
	_mothball_button.button_pressed = mothballed
	_mothball_button.set_block_signals(false)
	_apply_mothball_button_style(mothballed)


func _on_mothball_button_toggled(toggled_on: bool) -> void:
	if _resource_type == null:
		return
	EventBus.request_industry_mothball(_resource_type.type_name, toggled_on)
	_apply_mothball_button_style(toggled_on)


func _apply_mothball_button_style(mothballed: bool) -> void:
	_mothball_button.modulate = MOTHBALL_BUTTON_ACTIVE_COLOR if mothballed else MOTHBALL_BUTTON_NORMAL_COLOR


func _format_detail_value(resource_type: ResourceType, train: Train) -> String:
	var type_name := resource_type.type_name
	var current := train.get_res(type_name)
	var current_text := ResourceTypeRegistry.format_amount(type_name, current)
	if train.max_res.has(type_name):
		var max_text := ResourceTypeRegistry.format_amount(type_name, train.max_res[type_name])
		return "%s / %s" % [current_text, max_text]
	return current_text
