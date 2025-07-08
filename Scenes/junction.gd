extends Sprite2D

class_name Junction

@export var lines : Array[BranchLine] = []
var selector : int = 0
var last_changed_tick : int = 0
var tick_cooldown : int = 10
var looper : bool = false ## looper junctions are used to connect a train from one end of the worldmap to the opposite end of worldmap

func _ready():
	if lines.size() < 2:
		hide()	# hide junctions used only to rejoin tracks
		for line in lines:
			line.highlight_route(true)
	else:
		lines[selector].highlight_route(true)

func get_next_line() -> BranchLine:
	if lines.size() > 0:
		return lines[selector]
	return null

func highlight_selection():
	for line in lines:
		if line == lines[selector]:
			lines[selector].highlight_route(true)
		else:
			lines[selector].highlight_route(false)
		

func switch(viewport : Node, event : InputEvent, shape_idx : int):
	if event is InputEventMouseButton and event.is_action_pressed("left_click"):
		# prevent change if junction is still cooling down
		if (last_changed_tick + tick_cooldown) < Globals.game_tick or lines.size() < 2:
			return 
		print("Signal to change!")
		# Gray-out the previous branch line
		lines[selector].highlight_route(false)
		if selector + 1 < lines.size():
			selector += 1
		else:
			selector = 0
		
		# Highlight the new branch line
		lines[selector].highlight_route(true)
		
		last_changed_tick = Globals.game_tick

func transfer_train(trainMarker : PathFollow2D):
	lines[selector].add_train(trainMarker)
