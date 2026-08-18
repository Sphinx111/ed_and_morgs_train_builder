extends Node2D

## This represents a 'node' on the map where tracks should connect to
class_name MapLocation

## Ordered by settlement size so types can be compared numerically.
## Example: `location.type < TYPE.TOWN` is true for villages and map loopers.
enum TYPE {
	MAP_LOOPER = 0,
	VILLAGE = 1,
	TOWN = 2,
	CITY = 3,
}

var visual_radius : float = 8.0

var type: TYPE = TYPE.MAP_LOOPER
var edges: Array[MapGraphEdge] = []
var track_segments: Array[TrackSegment] = []
var track_selector: int = 0
var last_changed_tick: int = 0
var tick_cooldown: int = 10
var map_handler: MapHandler = null
var resource_containers : Dictionary = {}
var _debug_label: Label = null
var _click_area: Area2D = null


func _init(new_type: TYPE, map_position: Vector2 = Vector2.ZERO) -> void:
	type = new_type
	position = map_position
	_setup_visual()
	_setup_click_area()


func register_edge(edge: MapGraphEdge) -> void:
	if not edges.has(edge):
		edges.append(edge)


func register_track_segment(segment: TrackSegment) -> void:
	if not track_segments.has(segment):
		track_segments.append(segment)


func get_selected_track_segment() -> TrackSegment:
	if track_segments.is_empty():
		return null
	return track_segments[track_selector]


## When building the active route, pick a segment leaving this node.
## If the current selection is the incoming segment, switch to another (trunks first).
func select_outgoing_track(from_segment: TrackSegment) -> TrackSegment:
	if track_segments.is_empty():
		return null

	var selected := get_selected_track_segment()
	if from_segment == null or selected != from_segment:
		return selected

	if track_segments.size() <= 1:
		return selected

	var best_segment: TrackSegment = null
	var best_rank: int = 999
	for segment in track_segments:
		if segment == from_segment:
			continue
		var rank := _get_track_edge_rank(segment)
		if best_segment == null or rank < best_rank:
			best_segment = segment
			best_rank = rank

	if best_segment != null:
		track_selector = track_segments.find(best_segment)
	return best_segment if best_segment != null else selected


func _get_track_edge_rank(segment: TrackSegment) -> int:
	if segment == null or segment.map_edge == null:
		return 2
	match segment.map_edge.type:
		MapGraphEdge.EdgeType.TRUNK:
			return 0
		MapGraphEdge.EdgeType.BRANCH:
			return 1
		_:
			return 2


func highlight_track_selection() -> void:
	pass


func switch_track() -> void:
	if not can_switch_track():
		return
	track_selector += 1
	if track_selector >= track_segments.size():
		track_selector = 0
	last_changed_tick = Globals.game_tick
	if map_handler != null:
		map_handler.recalculate_active_route_from_train()


func can_switch_track() -> bool:
	if Globals.game_tick < (last_changed_tick + tick_cooldown):
		return false
	if track_segments.size() < 2:
		return false
	return true


func transfer_train(train_marker: PathFollow2D, from_segment: TrackSegment = null) -> void:
	if type == TYPE.MAP_LOOPER and map_handler != null:
		if map_handler.try_transfer_via_looper(train_marker as TrainMarker, self, from_segment):
			return

	var segment: TrackSegment = select_outgoing_track(from_segment)
	if segment == null:
		return
	if segment == from_segment:
		return
	if map_handler != null:
		map_handler.assign_train_to_track(segment, train_marker as TrainMarker)
	elif train_marker is TrainMarker:
		train_marker.enter_track(segment)


func _setup_visual() -> void:
	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.color = _get_type_color()
	visual_radius = _get_type_radius()
	visual.polygon = _make_circle_polygon(visual_radius, 16)
	add_child(visual)


func _setup_click_area() -> void:
	_click_area = Area2D.new()
	_click_area.name = "ClickArea"
	_click_area.input_pickable = false

	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = maxf(visual_radius * 2.0, 12.0)
	shape_node.shape = circle
	_click_area.add_child(shape_node)
	add_child(_click_area)
	_click_area.input_event.connect(_on_click_area_input_event)


func set_click_input_enabled(enabled: bool) -> void:
	if _click_area != null:
		_click_area.input_pickable = enabled


func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if map_handler == null or not map_handler.map_node_clicks_enabled:
		return
	if event is InputEventMouseButton and event.is_action_pressed("left_click"):
		switch_track()
		get_viewport().set_input_as_handled()


func _get_type_color() -> Color:
	match type:
		TYPE.CITY:
			return Color(1.0, 0.85, 0.2)
		TYPE.TOWN:
			return Color(0.4, 0.8, 1.0)
		TYPE.VILLAGE:
			return Color(0.7, 0.9, 0.5)
		TYPE.MAP_LOOPER:
			return Color(1.0, 0.3, 0.3)
		_:
			return Color.WHITE


func _get_type_radius() -> float:
	match type:
		TYPE.TOWN:
			return 6.0
		TYPE.VILLAGE:
			return 4.0
	return 8.0


func _make_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func get_resource_containers() -> Dictionary:
	return resource_containers

func add_resource_container(resourceType : String, container : MapResourceContainer) -> void:
	resource_containers.set(resourceType, container)
	_refresh_debug_view()


func _refresh_debug_view() -> void:
	if not Globals.MAP_GEN_DEBUG:
		if _debug_label != null:
			_debug_label.visible = false
		return

	if _debug_label == null:
		_setup_debug_label()

	_debug_label.text = _build_resource_debug_text()
	_debug_label.visible = not _debug_label.text.is_empty()


func _setup_debug_label() -> void:
	_debug_label = Label.new()
	_debug_label.name = "DebugResources"
	_debug_label.position = Vector2(visual_radius + 2.0, -visual_radius)
	_debug_label.z_index = 20
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_label.add_theme_font_size_override("font_size", 8)
	_debug_label.add_theme_color_override("font_color", Color.WHITE)
	_debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_debug_label.add_theme_constant_override("outline_size", 2)
	add_child(_debug_label)


func _build_resource_debug_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for resource_type in resource_containers:
		var container: MapResourceContainer = resource_containers[resource_type]
		if container == null:
			continue
		lines.append(container.get_debug_text())
	return "\n".join(lines)

func get_next_node_with_resource(_type : String, _attempts : int, _maxAttempts : int) -> MapLocation:
	if _attempts < _maxAttempts or type == TYPE.MAP_LOOPER:
		return null
	if resource_containers.has(_type):
		return self
	var track : TrackSegment = track_segments[track_selector]
	return track.get_other_node(self).get_next_node_with_resource(_type, _attempts + 1, _maxAttempts)
