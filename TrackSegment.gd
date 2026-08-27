extends Path2D

## Straight Path2D track for one MapGraph edge.
class_name TrackSegment

var map_edge: MapGraphEdge = null
var start_location: MapLocation = null
var end_location: MapLocation = null
var map_handler: MapHandler = null

var line: Line2D = null
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


func set_active(is_active: bool) -> void:
	active = is_active
	if line == null:
		return
	line.visible = is_active
	if is_active:
		line.default_color = Color.DIM_GRAY


func connects(location_a: MapLocation, location_b: MapLocation) -> bool:
	return (
		(start_location == location_a and end_location == location_b)
		or (start_location == location_b and end_location == location_a)
	)


func get_other_node(querying_node: MapLocation) -> MapLocation:
	if start_location == querying_node:
		return end_location
	if end_location == querying_node:
		return start_location
	return null


func connects_at_node(node: MapLocation) -> bool:
	return start_location == node or end_location == node


func is_entry_compatible(from_node: MapLocation, _travel_toward_end: bool = true) -> bool:
	if from_node == null:
		return true
	return connects_at_node(from_node)


func get_node_ahead(travel_toward_end: bool) -> MapLocation:
	return end_location if travel_toward_end else start_location


func get_node_behind(travel_toward_end: bool) -> MapLocation:
	return start_location if travel_toward_end else end_location


## Node ahead when travelling east on the map (Globals.train_direction > 0 toward end).
func get_next_node_for_travel(travel_direction: int) -> MapLocation:
	return get_node_ahead(travel_direction > 0)


func _draw_route_visual() -> void:
	if line != null:
		line.queue_free()

	line = Line2D.new()
	line.name = "Visual"
	line.width = _get_line_width()
	line.visible = false
	line.default_color = Color(0.7, 0.7, 0.7, 0.9)
	for point in curve.get_baked_points():
		line.add_point(point)
	add_child(line)


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
