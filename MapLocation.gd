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
var track_switcher: TrackJunction
var map_handler: MapHandler = null
var resource_containers : Array[MapResourceContainer] = []
var _debug_label: Label = null
var _click_area: Area2D = null
var _selector_debug_line: Line2D = null

const SELECTOR_DEBUG_LINE_LENGTH: float = 10.0
const SELECTOR_DEBUG_LINE_Z_INDEX: int = 50


func _init(new_type: TYPE, map_position: Vector2 = Vector2.ZERO) -> void:
	type = new_type
	position = map_position
	track_switcher = TrackJunction.new(self)
	_setup_visual()
	_setup_click_area()


func register_edge(edge: MapGraphEdge) -> void:
	if not edges.has(edge):
		edges.append(edge)


func register_track_segment(segment: TrackSegment) -> void:
	track_switcher.register_segment(segment)
	_refresh_selector_debug_line()


func sort_track_segments_clockwise() -> void:
	track_switcher.sort_segments_clockwise()
	_refresh_selector_debug_line()


func get_selected_track_segment() -> TrackSegment:
	return track_switcher.get_selected_segment()


func select_outgoing_track(from_segment: TrackSegment, travel_toward_end: bool = true) -> TrackSegment:
	var segment := track_switcher.pick_outgoing(from_segment, travel_toward_end)
	_refresh_selector_debug_line()
	return segment


func switch_track() -> void:
	if not can_switch_track():
		return
	track_switcher.cycle_manual()
	track_switcher.mark_switched()
	_refresh_selector_debug_line()
	if map_handler != null:
		map_handler.recalculate_active_route_from_train()


func can_switch_track() -> bool:
	if not track_switcher.can_switch():
		if track_segments.size() < 2:
			print("MapLocation:: failed connections size check")
		else:
			print("MapLocation:: failed cooldown check")
		return false
	return true


func transfer_train(train_marker: PathFollow2D, from_segment: TrackSegment = null) -> void:
	if type == TYPE.MAP_LOOPER and map_handler != null:
		if map_handler.try_transfer_via_looper(train_marker as TrainMarker, self, from_segment):
			return

	var marker := train_marker as TrainMarker
	var travel_toward_end := marker.travel_toward_end if marker != null else TrainMarker.travels_toward_end_on_map()
	var segment: TrackSegment = select_outgoing_track(from_segment, travel_toward_end)
	if segment == null:
		return
	if segment == from_segment:
		return
	if map_handler != null:
		map_handler.assign_train_to_track(segment, train_marker as TrainMarker, -1.0, self)
	elif train_marker is TrainMarker:
		(train_marker as TrainMarker).enter_track(segment, -1.0, self)


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

func get_resource_containers() -> Array[MapResourceContainer]:
	return resource_containers

func add_resource_container(container : MapResourceContainer) -> void:
	resource_containers.append(container)
	_refresh_debug_view()

func has_resource_type(_type : String) -> bool:
	for container in resource_containers:
		if container.resource_type == _type and not container.is_empty() and container.discovered:
			return true
	return false

func get_resource_container_of_type(_type : String) -> MapResourceContainer:
	for container in resource_containers:
		if container.resource_type == _type and not container.is_empty() and container.discovered:
			return container
	return null

func has_undiscovered_resources() -> bool:
	for container in resource_containers:
		if not container.discovered and not container.is_empty():
			return true
	return false

func discover_undiscovered_resources() -> void:
	for container in resource_containers:
		if not container.discovered and not container.is_empty():
			container.discovered = true
	_refresh_debug_view()

func discover_random_resource() -> MapResourceContainer:
	var candidates : Array[MapResourceContainer] = []
	for container in resource_containers:
		if not container.discovered and not container.is_empty():
			candidates.append(container)
	if candidates.is_empty():
		return null
	
	var total_weight : float = 0.0
	for container in candidates:
		total_weight += container.rarity
	
	var chosen : MapResourceContainer = null
	if total_weight <= 0.0:
		chosen = candidates[randi() % candidates.size()]
	else:
		var roll : float = randf() * total_weight
		var cumulative : float = 0.0
		for container in candidates:
			cumulative += container.rarity
			if roll < cumulative:
				chosen = container
				break
		if chosen == null:
			chosen = candidates[candidates.size() - 1]
	
	chosen.discovered = true
	_refresh_debug_view()
	return chosen


func _refresh_debug_view() -> void:
	if not Globals.MAP_GEN_DEBUG:
		if _debug_label != null:
			_debug_label.visible = false
		return

	if _debug_label == null:
		_setup_debug_label()

	_debug_label.text = _build_resource_debug_text()
	_debug_label.visible = not _debug_label.text.is_empty()
	_refresh_selector_debug_line()


func _setup_selector_debug_line() -> void:
	_selector_debug_line = Line2D.new()
	_selector_debug_line.name = "SelectorDebugLine"
	_selector_debug_line.width = 5
	_selector_debug_line.default_color = Color(1.0, 1.0, 0.35, 0.95)
	_selector_debug_line.visible = false
	_selector_debug_line.z_index = SELECTOR_DEBUG_LINE_Z_INDEX
	_selector_debug_line.z_as_relative = false
	_selector_debug_line.points = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT * SELECTOR_DEBUG_LINE_LENGTH])
	add_child(_selector_debug_line)
	move_child(_selector_debug_line, -1)


func _refresh_selector_debug_line() -> void:
	if _selector_debug_line == null:
		_setup_selector_debug_line()
	if not Globals.MAP_GEN_DEBUG:
		_selector_debug_line.visible = false
		return

	var segment := get_selected_track_segment()
	if segment == null:
		_selector_debug_line.visible = false
		return

	var other_node := segment.get_other_node(self)
	if other_node == null:
		_selector_debug_line.visible = false
		return

	var direction := other_node.position - position
	if direction.length_squared() <= 0.001:
		_selector_debug_line.visible = false
		return

	_selector_debug_line.set_point_position(0, Vector2.ZERO)
	_selector_debug_line.set_point_position(1, direction.normalized() * SELECTOR_DEBUG_LINE_LENGTH)
	_selector_debug_line.visible = true
	move_child(_selector_debug_line, -1)


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
	for container in resource_containers:
		if container == null:
			continue
		lines.append(container.get_debug_text())
	return "\n".join(lines)

func get_next_node_with_resource(
	_type : String,
	_attempts : int,
	_maxAttempts : int,
	_distance : float,
	from_segment: TrackSegment = null,
	travel_toward_end: bool = true
) -> MapDestination:
	if _attempts >= _maxAttempts or type == TYPE.MAP_LOOPER:
		return null
	if has_resource_type(_type):
		return MapDestination.new(_distance, self)

	var outgoing: TrackSegment = select_outgoing_track(from_segment, travel_toward_end)
	if outgoing == null:
		return null
	var next_node: MapLocation = outgoing.get_other_node(self)
	if next_node == null:
		return null
	return next_node.get_next_node_with_resource(
		_type,
		_attempts + 1,
		_maxAttempts,
		_distance + outgoing.curve.get_baked_length(),
		outgoing,
		travel_toward_end
	)
