extends Node2D

class_name Background

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

func _ready():
	for i in range(12):
		var rock : Sprite2D = Sprite2D.new()
		rock.centered = false
		rock.texture = rockImg
		rock.position.x = randf_range(-Globals.display_width, Globals.display_width)
		if i <= 6:
			rock.position.y += randf_range(-15, 0)
			$ForegroundLayer.add_child(rock)
			rock.scale = Vector2(0.6, 0.6)
			rocks_f.append(rock)
		else:
			rock.position.y += randf_range(-30, 60)
			$BackgroundLayer.add_child(rock)
			rock.scale = Vector2(0.4, 0.4)
			rocks_b.append(rock)

func _process(delta : float):
	for rock in rocks_b:
		rock.position.x = rock.position.x + (delta * 120)
		if rock.position.x > Globals.display_width:
			rock.position.x = 0 - randf_range(50, 120)
	
	for rock in rocks_f:
		rock.position.x = rock.position.x + (delta * 160)
		if rock.position.x > Globals.display_width:
			rock.position.x = 0 - randf_range(50, 120)
