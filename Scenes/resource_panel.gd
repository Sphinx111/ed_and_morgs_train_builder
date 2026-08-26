extends Panel

class_name ResourcePanel

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

const DETAIL_SCENE: PackedScene = preload("res://Scenes/resource_detail_panel.tscn")

@onready var _resource_rows: HBoxContainer = $ResourceRows

var _train: Train = null
var _speed_label: RichTextLabel = null
var _slots: Dictionary = {}
var _detail_panel: ResourceDetailPanel = null
var _hovered_slot: ResourceHoverSlot = null


func _ready() -> void:
	apply_panel_width()
	_setup_detail_panel()
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
	for slot in _slots.values():
		slot.bind_train(train)
	update_from_train(train)


func update_from_train(train: Train) -> void:
	_train = train
	if _speed_label != null:
		_speed_label.text = _format_speed(train)
	for slot in _slots.values():
		slot.refresh()
	if _detail_panel.visible and _hovered_slot != null:
		_detail_panel.show_for_resource(_hovered_slot.resource_type, train)


func _process(_delta: float) -> void:
	if _train != null and _speed_label != null:
		_speed_label.text = _format_speed(_train)


func _setup_detail_panel() -> void:
	_detail_panel = DETAIL_SCENE.instantiate()
	_detail_panel.z_index = 10
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_panel.hide_panel()
	_detail_panel.mouse_exited.connect(_on_detail_mouse_exited)
	add_child(_detail_panel)


func _build_resource_rows() -> void:
	for child in _resource_rows.get_children():
		child.queue_free()
	_slots.clear()

	_speed_label = RichTextLabel.new()
	_speed_label.name = "Speed"
	_speed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_label.scroll_active = false
	_speed_label.fit_content = true
	_resource_rows.add_child(_speed_label)

	for resource_type in RESOURCE_ROWS:
		var slot := ResourceHoverSlot.new()
		slot.name = resource_type.type_name
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		slot.custom_minimum_size = Vector2(72, 28)
		slot.configure(resource_type)
		slot.hover_started.connect(_on_slot_hover_started)
		slot.hover_ended.connect(_on_slot_hover_ended)
		if _train != null:
			slot.bind_train(_train)
		_resource_rows.add_child(slot)
		_slots[resource_type.type_name] = slot


func _on_slot_hover_started(slot: ResourceHoverSlot) -> void:
	_hovered_slot = slot
	_show_detail_for_slot(slot)


func _on_slot_hover_ended(_slot: ResourceHoverSlot) -> void:
	_schedule_hide_detail()


func _on_detail_mouse_exited() -> void:
	_schedule_hide_detail()


func _schedule_hide_detail() -> void:
	call_deferred("_update_detail_visibility")


func _update_detail_visibility() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	if _detail_panel.visible and _detail_panel.get_global_rect().has_point(mouse_pos):
		return
	if _hovered_slot != null and _hovered_slot.get_global_rect().has_point(mouse_pos):
		return
	_hide_detail()


func _show_detail_for_slot(slot: ResourceHoverSlot) -> void:
	if _train == null or slot.resource_type == null:
		return
	slot.refresh()
	_detail_panel.show_for_resource(slot.resource_type, _train)
	_position_detail_panel(slot)


func _position_detail_panel(slot: ResourceHoverSlot) -> void:
	var slot_rect := slot.get_global_rect()
	_detail_panel.global_position = slot_rect.position + Vector2(0.0, slot_rect.size.y)


func _hide_detail() -> void:
	_hovered_slot = null
	_detail_panel.hide_panel()


func _format_speed(train: Train) -> String:
	return "Speed: %s" % Helpers.pretty_print_float(train.speed)
