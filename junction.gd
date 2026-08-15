extends Sprite2D

class_name Junction

var connectionCount : int = 0
@export var lines : Array[BranchLine] = []
var selector : int = 0
var last_changed_tick : int = 0
var tick_cooldown : int = 10

func get_next_line() -> BranchLine:
	if lines.size() > 0:
		return lines[selector]
	return null

func highlight_selection():
	for line in lines:
		if line == lines[selector]:
			lines[selector].set_active(true)
		else:
			lines[selector].set_active(false)

func switch_track():
	if can_switch():
		lines[selector].set_active(false)
		selector += 1
		if selector >= lines.size():
			selector = 0
		lines[selector].set_active(true)
		last_changed_tick = Globals.game_tick

func can_switch() -> bool:
	if Globals.game_tick < (last_changed_tick + tick_cooldown):
		print("junction is on cooldown")
		return false
	elif lines.size() < 2:
		print("junction has no options")
		return false
	return true

func transfer_train(trainMarker : PathFollow2D):
	lines[selector].add_train(trainMarker)
	get_parent().get_parent().mainRoute = lines[selector]
