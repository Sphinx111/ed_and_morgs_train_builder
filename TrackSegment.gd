extends Path2D

## Straight Path2D track for one MapGraph edge; train follows via PathFollow2D.
class_name TrackSegment

var map_edge: MapGraphEdge = null
var start_location: MapLocation = null
var end_location: MapLocation = null
var map_handler: MapHandler = null

var line: Line2D = null
var train_marker: PathFollow2D = null
var active: bool = false


func configure(edge: MapGraphEdge, handler: MapHandler) -> void:
	map_edge = edge
	start_location = edge.node1
	end_location = edge.node2
	map_handler = handler
	position = Vector2.ZERO

	var track_curve := Curve2D.new()
	track_curve.add_point(start_location.position)
	track_curve.add_point(end_location.position)
	curve = track_curve
	_draw_route_visual()


func update_train_pos(progress: float) -> void:
	if train_marker == null:
		return

	train_marker.progress = train_marker.progress - (progress * Globals.train_direction)

	if Globals.train_direction < 0 and train_marker.progress_ratio >= 1.0:
		end_location.transfer_train(train_marker, self)
	elif Globals.train_direction > 0 and train_marker.progress_ratio <= 0.0:
		start_location.transfer_train(train_marker, self)


func add_train(marker: PathFollow2D) -> void:
	train_marker = marker
	if train_marker.get_parent() != null:
		train_marker.get_parent().remove_child(train_marker)
	add_child(train_marker)
	if Globals.train_direction < 0:
		train_marker.progress_ratio = 0.0
	elif Globals.train_direction > 0:
		train_marker.progress_ratio = 1.0


func set_active(is_active: bool) -> void:
	if line == null:
		return
	if is_active:
		line.default_color = Color(0.7, 0.7, 0.7, 0.9)
		active = true
	else:
		_apply_inactive_line_color()
		active = false


func connects(location_a: MapLocation, location_b: MapLocation) -> bool:
	return (
		(start_location == location_a and end_location == location_b)
		or (start_location == location_b and end_location == location_a)
	)


func _draw_route_visual() -> void:
	if line != null:
		line.queue_free()

	line = Line2D.new()
	line.name = "Visual"
	line.width = _get_line_width()
	_apply_inactive_line_color()
	for point in curve.get_baked_points():
		line.add_point(point)
	add_child(line)


func _apply_inactive_line_color() -> void:
	if line == null or map_edge == null:
		return

	match map_edge.type:
		MapGraphEdge.EdgeType.TRUNK:
			line.default_color = Color(0.85, 0.85, 0.35, 0.55)
		MapGraphEdge.EdgeType.BRANCH:
			line.default_color = Color(0.4, 0.8, 1.0, 0.45)
		_:
			line.default_color = Color(0.4, 0.4, 0.4, 0.4)


func _get_line_width() -> float:
	if map_edge == null:
		return 6.0

	match map_edge.type:
		MapGraphEdge.EdgeType.TRUNK:
			return 8.0
		MapGraphEdge.EdgeType.BRANCH:
			return 5.0
		_:
			return 4.0
