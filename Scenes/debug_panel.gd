extends Panel

class_name DebugPanel 

@onready var simSpeedSlider : HSlider = get_node("DebugSlider")	
var saveSpeed : float = 1

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			simSpeedSlider.value = 1
			simSpeedSlider.drag_ended.emit(true)
		if event.keycode == KEY_2:
			simSpeedSlider.value = 5
			simSpeedSlider.drag_ended.emit(true)
		if event.keycode == KEY_3:
			simSpeedSlider.value =  10
			simSpeedSlider.drag_ended.emit(true)
		if event.keycode == KEY_SPACE:
			if simSpeedSlider.value > 0 :
				saveSpeed = simSpeedSlider.value
				simSpeedSlider.value =  0
			else:
				simSpeedSlider.value = saveSpeed
			simSpeedSlider.drag_ended.emit(true)
