extends Control

class_name ResourceHoverSlot

signal hover_started(slot: ResourceHoverSlot)
signal hover_ended(slot: ResourceHoverSlot)

const SUMMARY_SCENE: PackedScene = preload("res://Scenes/resource_summary.tscn")

var resource_type: ResourceType = null

var _train: Train = null
var _summary: ResourceSummary = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func configure(type: ResourceType) -> void:
	resource_type = type
	if _summary != null:
		return

	_summary = SUMMARY_SCENE.instantiate()
	_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_summary)


func bind_train(train: Train) -> void:
	_train = train


func refresh() -> void:
	if _train == null or resource_type == null or _summary == null:
		return
	_summary.setup(resource_type, _train.get_res(resource_type.type_name), false)


func _on_mouse_entered() -> void:
	hover_started.emit(self)


func _on_mouse_exited() -> void:
	hover_ended.emit(self)
