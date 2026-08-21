extends Node2D

class_name MapHandler

@onready var map_graph_generator : MapGraphGenerator = $MapGraphGenerator
var resource_generator : MapResourceGenerator = MapResourceGenerator.new()
var map_graph : MapGraph = null
var active_track : TrackSegment = null
var _track_segments : Array[TrackSegment] = []

var trainMarker : TrainMarker = null      ## A visual marker for the train's position on the route
var selectedTrain : Train = null           ## A pointer to the player's train

var collection_margin : float = 30   ## Range at which resources can be collected
var local_to_global_speed_conversion : float = 0.005     # Multiple train's speed value by this to get worldmap pixels per tick

var sun1 : PathFollow2D = null
var sun2 : PathFollow2D = null
var sunradius : float = 512.0
var sun_path_length : float = 2048.0
var map_width : float = 1024.0
const MAP_CONTENT_SIZE : Vector2 = Vector2(1024.0, 723.0)
const MAX_RECURSE_SEARCH : int = 50
var sunspeed : float = 1.0
var map_node_clicks_enabled : bool = false

func _ready():
	trainMarker = get_node("TrainMarker") as TrainMarker
	trainMarker.map_handler = self
	trainMarker.loop = false
	sun1 = get_node("MapMask/Sunpath/Sun1")
	sun2 = get_node("MapMask/Sunpath/Sun2")
	_generate_and_apply_map()


func _generate_and_apply_map() -> void:
	if map_graph_generator == null:
		return
	apply_map_graph(map_graph_generator.regenerate_map())


func apply_map_graph(graph: MapGraph) -> void:
	map_graph = graph
	if map_graph == null:
		return
	_build_track_segments_from_graph(map_graph)
	resource_generator.add_resources_to_map_graph(map_graph)
	set_map_node_clicks_enabled(map_node_clicks_enabled)
	call_deferred("_place_train_on_active_route")


func set_map_node_clicks_enabled(enabled: bool) -> void:
	map_node_clicks_enabled = enabled
	if map_graph == null:
		return
	for location in map_graph.nodes:
		if is_instance_valid(location):
			location.set_click_input_enabled(enabled)


func regenerate_map() -> void:
	_recreate_train_marker()
	_generate_and_apply_map()


func _recreate_train_marker() -> TrainMarker:
	if trainMarker != null and is_instance_valid(trainMarker):
		trainMarker.queue_free()
	trainMarker = null

	var existing := get_node_or_null("TrainMarker")
	if existing != null:
		existing.queue_free()

	var marker := TrainMarker.new()
	marker.name = "TrainMarker"
	marker.loop = false
	marker.map_handler = self
	add_child(marker)

	var rect := ColorRect.new()
	rect.name = "Rect"
	rect.offset_top = -14.0
	rect.offset_right = 40.0
	rect.offset_bottom = 18.0
	marker.add_child(rect)

	trainMarker = marker
	return marker


func _build_track_segments_from_graph(graph: MapGraph) -> void:
	_clear_track_segments()
	if map_graph_generator == null:
		return

	var tracks_parent := _get_tracks_parent()
	for location in graph.nodes:
		location.track_segments.clear()
		location.map_handler = self

	for edge in graph.edges:
		if edge.node1 == null or edge.node2 == null:
			continue
		var segment := TrackSegment.new()
		segment.configure(edge, self)
		tracks_parent.add_child(segment)
		_track_segments.append(segment)
		edge.node1.register_track_segment(segment)
		edge.node2.register_track_segment(segment)

	for location in graph.nodes:
		location.sort_track_segments_clockwise()

	_deactivate_all_tracks()


func _deactivate_all_tracks() -> void:
	for segment in _track_segments:
		if is_instance_valid(segment):
			segment.set_active(false)


func _clear_track_segments() -> void:
	_detach_train_marker_from_routes()
	for segment in _track_segments:
		if is_instance_valid(segment):
			segment.queue_free()
	_track_segments.clear()
	active_track = null

	if map_graph != null:
		for location in map_graph.nodes:
			location.track_segments.clear()


func _resolve_train_marker() -> TrainMarker:
	if trainMarker == null or not is_instance_valid(trainMarker):
		trainMarker = get_node_or_null("TrainMarker") as TrainMarker
	if trainMarker != null and trainMarker.map_handler == null:
		trainMarker.map_handler = self
	return trainMarker


func _detach_train_marker_from_routes() -> void:
	var marker := _resolve_train_marker()
	if marker == null:
		active_track = null
		return

	marker.detach_to(self)
	active_track = null
	_deactivate_all_tracks()


func assign_train_to_track(
	segment: TrackSegment,
	marker: TrainMarker = null,
	progress_ratio: float = -1.0,
	from_node: MapLocation = null
) -> void:
	if marker == null:
		marker = _resolve_train_marker()
	if marker == null or segment == null:
		return
	active_track = segment
	marker.enter_track(segment, progress_ratio, from_node)
	recalculate_active_route(segment, marker)


func recalculate_active_route_from_train() -> void:
	var marker := _resolve_train_marker()
	if marker == null or marker.current_track == null:
		return
	recalculate_active_route(marker.current_track, marker)


func recalculate_active_route(start_segment: TrackSegment, marker: TrainMarker = null) -> void:
	_deactivate_all_tracks()
	if start_segment == null or not is_instance_valid(start_segment):
		return

	var travel_toward_end := marker.travel_toward_end if marker != null else Globals.train_direction < 0

	var current_segment: TrackSegment = start_segment
	var entry_node: MapLocation = null

	while current_segment != null:
		if current_segment.active:
			_log_active_route_termination("revisited active segment")
			break
		current_segment.set_active(true)

		var exit_node: MapLocation
		if entry_node == null:
			exit_node = current_segment.get_node_ahead(travel_toward_end)
		else:
			exit_node = current_segment.get_other_node(entry_node)

		if exit_node == null:
			break

		if exit_node.type == MapLocation.TYPE.MAP_LOOPER:
			var continue_segment := _get_continue_segment_after_looper(exit_node, travel_toward_end)
			if continue_segment == null:
				_log_active_route_termination("looper")
				break
			entry_node = map_graph.get_other_looper(exit_node) if map_graph != null else null
			if entry_node == null:
				_log_active_route_termination("looper")
				break
			current_segment = continue_segment
			continue

		var next_segment: TrackSegment = exit_node.select_outgoing_track(current_segment, travel_toward_end)
		if next_segment == null or next_segment == current_segment:
			break

		entry_node = exit_node
		current_segment = next_segment


func _count_active_track_segments() -> int:
	var count := 0
	for segment in _track_segments:
		if is_instance_valid(segment) and segment.active:
			count += 1
	return count


func _log_active_route_termination(reason: String) -> void:
	print("MapHandler: active route terminated at %s — %d active track segment(s)" % [reason, _count_active_track_segments()])


func _get_continue_segment_after_looper(looper_reached: MapLocation, travel_toward_end: bool) -> TrackSegment:
	if looper_reached == null or looper_reached.type != MapLocation.TYPE.MAP_LOOPER:
		return null
	if map_graph == null:
		return null
	var other_looper := map_graph.get_other_looper(looper_reached)
	if other_looper == null:
		return null
	return _find_continue_segment_from_looper(other_looper, travel_toward_end)


func try_transfer_via_looper(marker: TrainMarker, looper_reached: MapLocation, _from_segment: TrackSegment = null) -> bool:
	if marker == null or looper_reached == null or looper_reached.type != MapLocation.TYPE.MAP_LOOPER:
		return false
	if map_graph == null:
		return false

	var continue_segment := _get_continue_segment_after_looper(looper_reached, marker.travel_toward_end)
	if continue_segment == null:
		return false

	var other_looper := map_graph.get_other_looper(looper_reached)
	var entry_progress: float = 0.0 if continue_segment.start_location == other_looper else 1.0
	assign_train_to_track(continue_segment, marker, entry_progress, other_looper)
	return true


func _find_continue_segment_from_looper(looper: MapLocation, travel_toward_end: bool) -> TrackSegment:
	var candidates: Array[TrackSegment] = []
	for segment in looper.track_segments:
		if travel_toward_end and segment.start_location == looper:
			candidates.append(segment)
		elif not travel_toward_end and segment.end_location == looper:
			candidates.append(segment)

	for segment in candidates:
		if segment.map_edge != null and segment.map_edge.type == MapGraphEdge.EdgeType.TRUNK:
			return segment
	if not candidates.is_empty():
		return candidates[0]
	return null

func _get_tracks_parent() -> Node2D:
	var existing := map_graph_generator.get_node_or_null("TracksParent") as Node2D
	if existing == null:
		existing = Node2D.new()
		existing.name = "TracksParent"
		map_graph_generator.add_child(existing)
	return existing


func _place_train_on_active_route() -> void:
	var marker := _resolve_train_marker()
	if marker == null:
		return

	var segment := _find_main_route_start_segment()
	if segment == null:
		segment = _find_first_trunk_segment()
	if segment == null and not _track_segments.is_empty():
		segment = _track_segments[0]

	if segment == null:
		push_warning("MapHandler: no track segment available to place train")
		return

	assign_train_to_track(segment, marker, 0.5)


func _find_main_route_start_segment() -> TrackSegment:
	if map_graph == null:
		return null
	var route: Array[MapLocation] = map_graph.get_main_route()
	if route.size() < 2:
		return null
	return _find_segment_between(route[0], route[1])


func _find_first_trunk_segment() -> TrackSegment:
	for segment in _track_segments:
		if segment.map_edge != null and segment.map_edge.type == MapGraphEdge.EdgeType.TRUNK:
			return segment
	return null


func _ensure_train_on_active_track() -> bool:
	var marker := _resolve_train_marker()
	if marker == null:
		return false

	if marker.is_on_track():
		active_track = marker.current_track
		return true

	_place_train_on_active_route()
	if marker.is_on_track():
		active_track = marker.current_track
		return true

	return false


func _find_segment_between(location_a: MapLocation, location_b: MapLocation) -> TrackSegment:
	for segment in _track_segments:
		if segment.connects(location_a, location_b):
			return segment
	return null


func _update_train_position(progress: float) -> bool:
	var marker := _resolve_train_marker()
	if not _ensure_train_on_active_track() or marker == null:
		return false

	marker.advance(progress)
	active_track = marker.current_track
	return marker.current_track != null


func select_new_train(newTrain : Train) -> void:
	selectedTrain = newTrain

var scheduleStop : String = ""

func set_schedule_stop(resourceType):
	scheduleStop = resourceType

func train_step():
	if selectedTrain == null:
		return
	if not _update_train_position(selectedTrain.speed * local_to_global_speed_conversion):
		return
	sun1.progress -= sunspeed
	sun2.progress -= sunspeed
	update_time_to_sun()
	# Debug testing - Next oil spot
	if scheduleStop != "" :
		var nextTarget : MapDestination = get_next_resource_spot(scheduleStop)
		if nextTarget != null:
			print("Next %s Well has %s units and is at %f" % [scheduleStop, nextTarget.target.resource_containers.get(scheduleStop).amount, nextTarget.distance])
			if nextTarget.distance <100 :
				selectedTrain.target_speed = 100
			if nextTarget.distance < 50 : 
				selectedTrain.target_speed = 0 

func get_node_in_range(_range : float) -> MapLocation:
	if trainMarker == null:
		return null
	return trainMarker.get_nearby_node(_range)

func request_resources(_wantedType : String) -> float:
	return 0.0

func gather_resource(_wantedType : String, _amount : float) -> int:
	return 0

func query_resource_types() -> Dictionary[String, MapResourceContainer]:
	var nearestLocation : MapLocation = get_node_in_range(collection_margin)
	if nearestLocation != null:
		return nearestLocation.get_resource_containers()
	return {}

func get_next_resource_spot(_type : String) -> MapDestination:
	if trainMarker == null or trainMarker.current_track == null:
		return null
	var ahead_node := trainMarker.get_travel_exit_node()
	var distance_remaining := trainMarker.get_distance_remaining_on_segment()
	return ahead_node.get_next_node_with_resource(
		_type,
		0,
		MAX_RECURSE_SEARCH,
		distance_remaining,
		trainMarker.current_track,
		trainMarker.travel_toward_end
	)

func get_distance_to_next_resource(_type : String) -> float:
	var nextDestination : MapDestination = get_next_resource_spot(_type)
	if nextDestination == null:
		return -9999
	else:
		return nextDestination.distance


func is_train_in_sun() -> bool:
	#print("trainPos: %f sun1pos: %f sun2pos: %f" % [trainMarker.position.x, sun1.position.x, sun2.position.x])
	if trainMarker.position.x > sun1.position.x and trainMarker.position.x < sun1.position.x + sunradius:
		print("train is in sunlight")
		return true
	elif trainMarker.position.x > sun2.position.x and trainMarker.position.x < sun2.position.x + sunradius:
		print("train is in sunlight")
		return true
	return false

func is_position_in_sun(testPos : Vector2) -> bool:
	if testPos.x > sun1.position.x and testPos.x < sun1.position.x + sunradius:
		return true
	elif testPos.x > sun2.position.x and testPos.x < sun2.position.x + sunradius:
		return true
	return false

func get_sun_height_for_train() -> float:
	return get_sun_height(trainMarker.position)

## Get the sun's height in the sky from a given position.
## Returns -1 when not in sunlight, otherwise 0.0 (left horizon) to 2.0 (right horizon),
## with 1.0 at the seam where the two sun objects meet.
func get_sun_height(testPosition : Vector2) -> float:
	var test_x : float = testPosition.x

	if test_x >= sun1.position.x and test_x < sun1.position.x + sunradius:
		return (test_x - sun1.position.x) / sunradius

	if test_x >= sun2.position.x and test_x < sun2.position.x + sunradius:
		return 1.0 + (test_x - sun2.position.x) / sunradius

	return -1.0

## Important: Returns distance to midpoint of a sun
func get_distance_to_any_sun(testPosition : Vector2) -> float:
	var distance_in_pixels : float = 0
	var dist_to_sun1 : float = sun1.position.x + (sunradius/2) - testPosition.x
	var dist_to_sun2 : float = sun2.position.x + (sunradius/2) - testPosition.x
	# If sun 1 is the closest sun, return distance to it
	if abs(dist_to_sun1) <  abs(dist_to_sun2):
		distance_in_pixels = sun1.position.x + (sunradius/2) - testPosition.x
	else:
		distance_in_pixels = sun2.position.x + (sunradius/2) - testPosition.x

	return distance_in_pixels

func get_distance_to_next_sun(testPosition : Vector2) -> float:
	var distance_in_pixels : float = 0
	var dist_to_sun1 : float = sun1.position.x - testPosition.x
	var dist_to_sun2 : float = sun2.position.x - testPosition.x
	if dist_to_sun1 > 0 and dist_to_sun2 > 0:
		distance_in_pixels = min(sun1.position.x - testPosition.x, sun2.position.x - testPosition.x)
	elif dist_to_sun1 > 0:
		distance_in_pixels = sun1.position.x - testPosition.x
	else:
		distance_in_pixels = sun2.position.x - testPosition.x
	return distance_in_pixels

func update_time_to_sun():
	#var train_speed_in_pixels : float = local_to_global_speed_conversion * selectedTrain.speed
	#train_speed_in_pixels = cos(abs(trainMarker.rotation)) * train_speed_in_pixels
	var sun_speed_in_pixels : float = sunspeed
	var distance_in_pixels : float = 0.0
	distance_in_pixels = get_distance_to_next_sun(trainMarker.position)
	var time_to_sun =  distance_in_pixels / (sun_speed_in_pixels) #- train_speed_in_pixels)
	if time_to_sun > 0:
		var displayText = Helpers.seconds_to_mm_ss(time_to_sun)
		get_node("TimeToSun").text = displayText
	else:
		get_node("TimeToSun").text = "N/A"
