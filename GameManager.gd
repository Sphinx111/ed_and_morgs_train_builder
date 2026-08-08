extends Control

var mainCamera : Camera2D = null
var ui_tree : Control = null
var background : Node2D = null
var shift_per_press : float = Globals.car_length + Globals.car_separation
var targetPosition : Vector2 = Vector2.ZERO


func _ready() -> void:
	get_viewport().size_changed.connect(_configure_root_layout)
	mainCamera = get_node("Camera2D")
	ui_tree = get_node("BasicUI")
	background = get_node("Background")
	_configure_root_layout()
	mainCamera.position_smoothing_enabled = true
	mainCamera.position_smoothing_speed = 2000.0
	targetPosition = mainCamera.offset


func _configure_root_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ui_tree != null:
		ui_tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var action : InputEventKey = event
		if action.is_action_pressed("camera_left"):
			print("camera_left pressed")
			targetPosition.x -= shift_per_press
			ui_tree.position.x -= shift_per_press
			background.position.x -= shift_per_press
		elif action.is_action_pressed("camera_right"):
			targetPosition.x += shift_per_press
			ui_tree.position.x += shift_per_press
			background.position.x += shift_per_press
			print("camera_right pressed")
		mainCamera.offset = targetPosition


func _process(_delta : float) -> void:
	pass
