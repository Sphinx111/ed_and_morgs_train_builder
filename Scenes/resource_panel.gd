extends Panel

class_name ResourcePanel

const RESOURCE_SUMMARY_SCENE: PackedScene = preload("res://Scenes/resource_summary.tscn")

const RESOURCE_ROWS: Array[ResourceType] = [
	ResourceTypeRegistry.TYPE_FUEL,
	ResourceTypeRegistry.TYPE_POP,
	ResourceTypeRegistry.TYPE_CLEAN_WATER,
	ResourceTypeRegistry.TYPE_GREY_WATER,
	ResourceTypeRegistry.TYPE_BLACK_WATER,
	ResourceTypeRegistry.TYPE_MECH_PARTS,
	ResourceTypeRegistry.TYPE_FOOD1,
	ResourceTypeRegistry.TYPE_SCRAP,
	ResourceTypeRegistry.TYPE_OIL,
]

@onready var _resource_rows: HBoxContainer = $ResourceRows
@onready var _detail_panel: Panel = $ResourceDetailPanel
@onready var _type_label: Label = $ResourceDetailPanel/TypeLabel
@onready var _value_label: Label = $ResourceDetailPanel/ValueLabel

var _train: Train = null
var _speed_label: RichTextLabel = null
var _summaries: Dictionary = {}
var _hover_signals_connected: bool = false


func _ready() -> void:
	apply_panel_width()
	_detail_panel.hide()
	_detail_panel.z_index = 1
	_build_resource_rows()


func apply_panel_width() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = Globals.resource_panel_width_percent / 100.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = Globals.resource_panel_height


func setup(train: Train) -> void:
	_train = train
	_setup_hover_signals()
	update_from_train(train)


func update_from_train(train: Train) -> void:
	_train = train
	if _speed_label != null:
		_speed_label.text = _format_speed(train)
	for resource_type in RESOURCE_ROWS:
		var summary: ResourceSummary = _summaries.get(resource_type.type_name)
		if summary == null:
			continue
		summary.setup(resource_type, _get_row_amount(resource_type, train), false)


func _process(_delta: float) -> void:
	if _train != null and _speed_label != null:
		_speed_label.text = _format_speed(_train)


func _build_resource_rows() -> void:
	for child in _resource_rows.get_children():
		child.queue_free()
	_summaries.clear()
	_hover_signals_connected = false

	_speed_label = RichTextLabel.new()
	_speed_label.name = "Speed"
	_speed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_label.scroll_active = false
	_speed_label.fit_content = true
	_resource_rows.add_child(_speed_label)

	for resource_type in RESOURCE_ROWS:
		var summary: ResourceSummary = RESOURCE_SUMMARY_SCENE.instantiate()
		summary.name = resource_type.type_name
		summary.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_resource_rows.add_child(summary)
		_summaries[resource_type.type_name] = summary


func _format_speed(train: Train) -> String:
	return "Speed: %s" % Helpers.pretty_print_float(train.speed)


func _get_row_amount(resource_type: ResourceType, train: Train) -> float:
	if train == null or resource_type == null:
		return 0.0
	return train.get_res(resource_type.type_name)


func _setup_hover_signals() -> void:
	if _hover_signals_connected:
		return
	for resource_type in RESOURCE_ROWS:
		var summary: ResourceSummary = _summaries.get(resource_type.type_name)
		if summary == null:
			continue
		summary.mouse_entered.connect(_on_resource_hover.bind(resource_type, summary))
		summary.mouse_exited.connect(_on_resource_leave)
	_hover_signals_connected = true


func _format_detail_value(resource_type: ResourceType) -> String:
	var type_name := resource_type.type_name
	var current := _train.get_res(type_name)
	var current_text := ResourceTypeRegistry.format_amount(type_name, current)
	if _train.max_res.has(type_name):
		var max_text := ResourceTypeRegistry.format_amount(type_name, _train.max_res[type_name])
		return "%s / %s" % [current_text, max_text]
	return current_text


func _position_detail_panel(summary: ResourceSummary) -> void:
	_detail_panel.position.x = _resource_rows.position.x + summary.position.x
	_detail_panel.position.y = _resource_rows.position.y + _resource_rows.size.y


func _on_resource_hover(resource_type: ResourceType, summary: ResourceSummary) -> void:
	if _train == null:
		return
	_position_detail_panel(summary)
	_type_label.text = resource_type.display_name
	_value_label.text = _format_detail_value(resource_type)
	_detail_panel.show()


func _on_resource_leave() -> void:
	_detail_panel.hide()
