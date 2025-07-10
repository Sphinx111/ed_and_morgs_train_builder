extends Node2D

class_name LeverControl

@onready var handle : PathFollow2D = get_node("LeverPath/Lever")
var isDragged : bool = false
var lastMousePos : Vector2 = Vector2.ZERO
var distanceToMove : float = 200.0
var speedSteps : float = 5.0
var currentStep : float = 2.0
var lastStep : float = 2.0
signal position_changed(new_position : int)


func _on_lever_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.is_action_pressed("left_click"):
		isDragged = true
		lastStep = currentStep
	pass # Replace with function body.

func _input(event: InputEvent) -> void:
	if isDragged == true:
		if event is InputEventMouseButton:
			if event.is_action_released("left_click"):
				isDragged = false
				if currentStep != lastStep:
					lastStep = clamp(lastStep, 0, 5)
					currentStep = clamp(currentStep, 0, 5)
					var int_to_emit : int = floor(currentStep)
					position_changed.emit(currentStep)
		elif event is InputEventMouseMotion:
			var move : InputEventMouseMotion = event
			var deltaVector = (move.position - lastMousePos)
			var deltaProduct = deltaVector.x * abs(deltaVector.y)
			if deltaProduct > distanceToMove:
				currentStep += 1
				clampf(currentStep, 0, speedSteps)
				lastMousePos = move.position
				handle.progress_ratio = (currentStep / speedSteps)
			elif deltaProduct < -distanceToMove:
				currentStep -= 1
				clampf(currentStep, 0, speedSteps)
				lastMousePos = move.position
				handle.progress_ratio = (currentStep / speedSteps)
