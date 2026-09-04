extends Node2D

class_name MapHandler

@onready var map_graph_generator : MapGraphGenerator = $MapGraphGenerator
@onready var continent_generator : MapContinentGenerator = $MapContinentGenerator
var resource_generator : MapResourceGenerator = MapResourceGenerator.new()
var map_graph : MapGraph = null
var active_track : TrackSegment = null
var _track_segments : Array[TrackSegment] = []

@onready var sun : MapSun = $MapMask/Sunpath
@onready var _time_to_sun_label : Label = $TimeToSun

var trainMarker : TrainMarker = null      ## A visual marker for the train's position on the route
var selectedTrain : Train = null           ## A pointer to the player's train

var collection_margin : float = 30   ## Range at which resources can be collected
@export var local_to_global_speed_conversion : float = Globals.local_to_global_speed_conversion     # Multiple train's speed value by this to get worldmap pixels per tick

const MAP_CONTENT_SIZE : Vector2 = Vector2(1024.0, 723.0)
const MAX_RECURSE_SEARCH : int = 50
var map_node_clicks_enabled : bool = false
var schedulePanel : StopSchedulePanel = null

func _ready():
	trainMarker = get_node("TrainMarker") as TrainMarker
	trainMarker.map_handler = self
	trainMarker.loop = false
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
	if continent_generator != null:
		continent_generator.create_grids_from_mapGraph(map_graph)
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
	rect.offset_top = -10.0
	rect.offset_right = 40.0
	rect.offset_bottom = 10.0
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

	var travel_toward_end := marker.travel_toward_end if marker != null else TrainMarker.travels_toward_end_on_map()

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
	sun.advance()
	sun.update_time_label(trainMarker.position, _time_to_sun_label)
	if scheduleStop != "" : # TODO: at some point for efficiency we might wanna not run this EVERY tick
		check_schedule()
		
		
func check_schedule() :
	var nextTarget : MapDestination = get_next_resource_spot(scheduleStop)
	if nextTarget != null:
		var scheduled_container : MapResourceContainer = nextTarget.target.get_resource_container_of_type(scheduleStop)
		if scheduled_container != null:
			print("Next %s Well has %s units and is at %f" % [scheduleStop, scheduled_container.amount, nextTarget.distance])
		if nextTarget.distance < 100 :
			if selectedTrain.target_speed > 200 : # don't speed up to 200
				selectedTrain.target_speed = 200 # but do slow down to it
			if nextTarget.distance <60 :
				selectedTrain.target_speed = 100 #not checking this one since it only comes up 
				 #if you're stopped and the next well is so close you might as well start it
				if nextTarget.distance < 10 : 
					selectedTrain.target_speed = 0 
					scheduleStop = "" #clear the schedule so you can start the train again
					

func get_node_in_range(_range : float) -> MapLocation:
	if trainMarker == null:
		return null
	return trainMarker.get_nearby_node(_range)

func get_nodes_in_range(_range : float) -> Array[MapLocation]:
	if trainMarker == null:
		return []
	return trainMarker.get_nearby_nodes(_range)

func request_resources(_wantedType : String) -> float:
	return 0.0

func gather_resource(_wantedType : String, _amount : float) -> int:
	return 0

func query_resource_types() -> Array[MapResourceContainer]:
	var result : Array[MapResourceContainer] = []
	for location in get_nodes_in_range(collection_margin):
		for container in location.get_resource_containers():
			if container.resource_type == MapResourceLocation.RESOURCE_TYPE:
				continue
			if container.is_empty() or not container.discovered:
				continue
			result.append(container)
	return result


func query_train_car_yards() -> Array[MapResourceContainer]:
	var result : Array[MapResourceContainer] = []
	for location in get_nodes_in_range(collection_margin):
		for container in location.get_resource_containers():
			if container.resource_type != MapResourceLocation.RESOURCE_TYPE:
				continue
			if container.is_empty() or not container.discovered:
				continue
			result.append(container)
	return result

func query_scavenge_locations() -> Array[MapLocation]:
	var result : Array[MapLocation] = []
	for location in get_nodes_in_range(collection_margin):
		if location.has_undiscovered_resources() and not result.has(location):
			result.append(location)
	return result

func get_next_resource_spot(_type : String) -> MapDestination:
	if trainMarker == null or trainMarker.current_track == null :
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


func get_sun_height_for_train() -> float:
	if trainMarker == null:
		return -1.0
	return sun.get_sun_height(trainMarker.position)

func get_sun_height(map_position : Vector2) -> float:
	return sun.get_sun_height(map_position)

func is_position_in_sun(map_position : Vector2) -> bool:
	return sun.is_position_in_sun(map_position)

func get_sun_temperature_at(map_position : Vector2) -> float:
	return sun.get_temperature_at(map_position)

func get_sun_temperature_for_train() -> float:
	if trainMarker == null:
		return Globals.train_base_temp
	return sun.get_temperature_at(trainMarker.position)

func get_time_until_sun_reaches(map_position : Vector2) -> float:
	return sun.get_time_until_reaches(map_position)
