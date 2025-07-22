extends Node2D

class_name BackgroundManager

var rockImg = preload("res://images/Rock1.png")

var rocks_f : Array = []
var rocks_b : Array = []

@onready
var foreground_height = $ForegroundLayer.position.y
@onready
var background_height = $BackgroundLayer.position.y
@onready
var fg = $ForegroundLayer
@onready
var bg = $BackgroundLayer
@onready var sunbeam = $Sunbeam

var reference_speed : float = 100.00
var train : Train = null

func _ready():
	train = get_node("../Train")
	for i in range(12):
		var rock : Sprite2D = Sprite2D.new()
		rock.centered = false
		rock.texture = rockImg
		if Globals.train_direction > 0: rock.position.x = randf_range(0 , 2 * Globals.display_width)
		elif Globals.train_direction < 0: rock.position.x = randf_range(-Globals.display_width , Globals.display_width)
		if i <= 6:
			rock.position.y += randf_range(-15, 0)
			$ForegroundLayer.add_child(rock)
			rock.scale = Vector2(0.6, 0.6)
			rocks_f.append(rock)
		else:
			rock.position.y += randf_range(-30, 0)
			$BackgroundLayer.add_child(rock)
			rock.scale = Vector2(0.4, 0.4)
			rocks_b.append(rock)

func _process(delta : float):
	for rock in rocks_b:
		rock.position.x = rock.position.x - (Globals.train_direction * (delta * 120) * Globals.time_factor * train.speed / reference_speed)
		if rock.position.x < -20 or rock.position.x > Globals.display_width + 120:
			if Globals.train_direction > 0: rock.position.x = Globals.display_width + randf_range(50, 120)
			elif Globals.train_direction < 0: rock.position.x = 0 - randf_range(50, 120)
	
	for rock in rocks_f:
		rock.position.x = rock.position.x - (Globals.train_direction * (delta * 160) * Globals.time_factor * train.speed / reference_speed)
		if rock.position.x < -20 or rock.position.x > Globals.display_width + 120:
			if Globals.train_direction > 0: rock.position.x = Globals.display_width + randf_range(50, 110)
			elif Globals.train_direction < 0: rock.position.x = 0 - randf_range(50, 120)

func update_sun_state():
	var sun_height : float = train.worldMap.get_sun_height_for_train()
	if sun_height <= -1:
		sunbeam.hide()
	else:
		sunbeam.show()
		sunbeam.rotation = (1 * PI) - ((0.5 * PI) * sun_height)
	pass
