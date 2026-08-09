extends Panel

class_name ResourcePanel

const ROWS: Array[Dictionary] = [
	{"node_name": "Speed", "display_label": "Speed", "type": "speed"},
	{"node_name": "Fuel", "display_label": "Fuel", "type": "resource", "key": "fuel"},
	{"node_name": "Pop", "display_label": "Pop", "type": "pop"},
	{"node_name": "CleanWater", "display_label": "Water", "type": "resource", "key": "clean_water"},
	{"node_name": "GreyWater", "display_label": "Grey", "type": "resource", "key": "grey_water"},
	{"node_name": "BlackWater", "display_label": "Black", "type": "resource", "key": "black_water"},
	{"node_name": "MechParts", "display_label": "Parts", "type": "resource", "key": "mech_parts"},
	{"node_name": "Food", "display_label": "Food", "type": "resource", "key": "food1"},
	{"node_name": "Scrap", "display_label": "Scrap", "type": "resource", "key": "scrap"},
	{"node_name": "Oil", "display_label": "Oil", "type": "resource", "key": "oil"},
]

@onready var _resource_rows: HBoxContainer = $ResourceRows
@onready var _detail_panel: Panel = $ResourceDetailPanel
@onready var _type_label: Label = $ResourceDetailPanel/TypeLabel
@onready var _value_label: Label = $ResourceDetailPanel/ValueLabel

var _train: Train = null


func _ready() -> void:
	apply_panel_width()
	_detail_panel.hide()
	_configure_row_labels()


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


func update_from_train(train: Train) -> void:
	_train = train
	for row in ROWS:
		var label: RichTextLabel = _get_row_label(row["node_name"])
		label.text = _format_row(row, train)

func _process(delta : float) -> void:
	if _train != null:
		var label : RichTextLabel = _get_row_label("Speed")
		if label!= null:
			label.text = _format_row(ROWS[0], _train)

func _configure_row_labels() -> void:
	for row in ROWS:
		var label: RichTextLabel = _get_row_label(row["node_name"])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.scroll_active = false


func _format_row(row: Dictionary, train: Train) -> String:
	match row["type"]:
		"speed":
			return "%s: %s" % [row["display_label"], Helpers.pretty_print_float(train.speed)]
		"pop":
			return "%s: %s" % [row["display_label"], String.num_int64(train.passengerManager.passengers.size())]
		"resource":
			return "%s: %s" % [row["display_label"], Helpers.pretty_print_float(train.get_res(row["key"]))]
	return ""


func _setup_hover_signals() -> void:
	for row in ROWS:
		if row["type"] != "resource":
			continue
		var label: RichTextLabel = _get_row_label(row["node_name"])
		var resource_key: String = row["key"]
		label.mouse_entered.connect(_on_resource_hover.bind(resource_key, label))
		label.mouse_exited.connect(_on_resource_leave)


func _on_resource_hover(resource_key: String, label: RichTextLabel) -> void:
	_detail_panel.position.x = label.position.x
	_type_label.text = resource_key

	if _train.res.has(resource_key) and _train.max_res.has(resource_key):
		_value_label.text = "%s / %s" % [
			Helpers.pretty_print_float(_train.res[resource_key]),
			Helpers.pretty_print_float(_train.max_res[resource_key]),
		]
		_detail_panel.show()


func _on_resource_leave() -> void:
	_detail_panel.hide()


func _get_row_label(node_name: String) -> RichTextLabel:
	return _resource_rows.get_node(node_name) as RichTextLabel
