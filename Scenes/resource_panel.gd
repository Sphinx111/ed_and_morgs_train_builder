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

@onready var _detail_panel: Panel = $ResourceDetailPanel
@onready var _type_label: Label = $ResourceDetailPanel/TypeLabel
@onready var _value_label: Label = $ResourceDetailPanel/ValueLabel

var _train: Train = null


func _ready() -> void:
	_detail_panel.hide()


func setup(train: Train) -> void:
	_train = train
	_setup_hover_signals()


func update_from_train(train: Train) -> void:
	_train = train
	for row in ROWS:
		var label: RichTextLabel = get_node(row["node_name"])
		label.text = _format_row(row, train)


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
		var label: RichTextLabel = get_node(row["node_name"])
		var resource_key: String = row["key"]
		label.mouse_entered.connect(_on_resource_hover.bind(resource_key, label.position.x))
		label.mouse_exited.connect(_on_resource_leave)


func _on_resource_hover(resource_key: String, x_pos: float) -> void:
	_detail_panel.position.x = x_pos
	_type_label.text = resource_key

	if _train.res.has(resource_key) and _train.max_res.has(resource_key):
		_value_label.text = "%s / %s" % [
			Helpers.pretty_print_float(_train.res[resource_key]),
			Helpers.pretty_print_float(_train.max_res[resource_key]),
		]
		_detail_panel.show()


func _on_resource_leave() -> void:
	_detail_panel.hide()
