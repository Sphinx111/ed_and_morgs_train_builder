extends PathFollow2D

class_name ResourceSpot

var resource_type : String = "scrap"
var quantity : float = 250.00
var colorRect : ColorRect = null
var myColor : Color = Color.SANDY_BROWN

@onready
var parentRoute : Path2D = get_parent()
var relative_pos : float = 0.1
var visual_scale : float = 1
var offset : Vector2 = Vector2(0,2)

func _ready():
	colorRect = ColorRect.new()
	add_child(colorRect)
	colorRect.size = Vector2(4.0, 4.0) * visual_scale
	colorRect.color = myColor
	colorRect.position += offset
	
	progress_ratio = relative_pos

func set_stats(newType : String, newQty : float):
	resource_type = newType
	quantity = newQty
	
	if resource_type == "pop":
		myColor = Color.PURPLE
		colorRect.color = myColor
