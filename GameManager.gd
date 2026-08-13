extends Control

@onready var ui_tree: Control = get_node("UICanvas/BasicUI")
var currentTrain : Train
var narrativeEngine : NarrativeEngine

func _ready() -> void:
	get_viewport().size_changed.connect(_configure_root_layout)
	_configure_root_layout()
	currentTrain = get_node("Train")
	narrativeEngine = NarrativeEngine.new(currentTrain)
	add_child(narrativeEngine)
	narrativeEngine.start()


func _configure_root_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ui_tree != null:
		ui_tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
