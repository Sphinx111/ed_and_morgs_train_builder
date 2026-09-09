extends Control

class_name ResourceTrendIndicator

## Small triangle overlay shown on a resource's box to give an at-a-glance read on
## whether the train produced more of that resource than it consumed (or vice versa)
## over the last resource tick. Sits just above the box (pointing up) when producing,
## or just below the box (pointing down) when consuming, and is hidden when net-unchanged.

const INDICATOR_SIZE : Vector2 = Vector2(12.0, 7.0)
const PRODUCING_COLOR : Color = Color(0.45, 0.85, 0.4, 1.0)
const CONSUMING_COLOR : Color = Color(0.9, 0.35, 0.3, 1.0)

var _trend : int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_trend()


## trend: 1 = net production this tick (up arrow, sits above the box),
## -1 = net consumption this tick (down arrow, sits below the box),
## 0 = no net change (hidden).
func set_trend(trend : int) -> void:
	if trend == _trend:
		return
	_trend = trend
	_apply_trend()


func _apply_trend() -> void:
	if not is_inside_tree():
		return
	match _trend:
		1:
			# Anchored to the box's top-center edge; the triangle sits above it, pointing up.
			anchor_left = 0.5
			anchor_right = 0.5
			anchor_top = 0.0
			anchor_bottom = 0.0
			offset_left = -INDICATOR_SIZE.x / 2.0
			offset_right = INDICATOR_SIZE.x / 2.0
			offset_top = -INDICATOR_SIZE.y
			offset_bottom = 0.0
			visible = true
		-1:
			# Anchored to the box's bottom-center edge; the triangle sits below it, pointing down.
			anchor_left = 0.5
			anchor_right = 0.5
			anchor_top = 1.0
			anchor_bottom = 1.0
			offset_left = -INDICATOR_SIZE.x / 2.0
			offset_right = INDICATOR_SIZE.x / 2.0
			offset_top = 0.0
			offset_bottom = INDICATOR_SIZE.y
			visible = true
		_:
			visible = false
	queue_redraw()


func _draw() -> void:
	if _trend == 0:
		return
	var color : Color = PRODUCING_COLOR if _trend == 1 else CONSUMING_COLOR
	var points : PackedVector2Array
	if _trend == 1:
		points = PackedVector2Array([
			Vector2(size.x / 2.0, 0.0),
			Vector2(size.x, size.y),
			Vector2(0.0, size.y),
		])
	else:
		points = PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(size.x, 0.0),
			Vector2(size.x / 2.0, size.y),
		])
	draw_colored_polygon(points, color)
