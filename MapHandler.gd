extends Node2D

class_name MapHandler

@onready var map_graph_generator : MapGraphGenerator = $MapGraphGenerator
var resource_generator : MapResourceGenerator = MapResourceGenerator.new()
var map_graph : MapGraph = null
var active_track : TrackSegment = null
var _track_segments : Array[TrackSegment] = []

var mainRoute : BranchLine = null          ## Legacy route; superseded by active_track when set
var trainMarker : PathFollow2D = null      ## A visual marker for the train's position on the route
var selectedTrain : Train = null           ## A pointer to the player's train

var collection_margin : float = 30   ## Range at which resources can be collected
var local_to_global_speed_conversion : float = 0.005     # Multiple train's speed value by this to get worldmap pixels per tick

var sun1 : PathFollow2D = null
var sun2 : PathFollow2D = null
var sunradius : float = 512.0
var sun_path_length : float = 2048.0
var map_width : float = 1024.0
const MAP_CONTENT_SIZE : Vector2 = Vector2(1024.0, 723.0)
var sunspeed : float = 1.0

func _enter_tree() -> void:
	var generator: MapGraphGenerator = get_node_or_null("MapGraphGenerator") as MapGraphGenerator
	if generator != null and not generator.map_graph_generated.is_connected(_on_map_graph_generated):
		generator.map_graph_generated.connect(_on_map_graph_generated)


func _ready():
	mainRoute = get_node("MainRoute")
	trainMarker = get_node("TrainMarker")
	trainMarker.loop = false
	sun1 = get_node("MapMask/Sunpath/Sun1")
	sun2 = get_node("MapMask/Sunpath/Sun2")
	if map_graph != null:
		_place_train_on_active_route()
	else:
		assign_train_to_legacy_route(trainMarker)
		trainMarker.progress_ratio = 0.5


func _on_map_graph_generated(graph: MapGraph) -> void:
	map_graph = graph
	if map_graph == null:
		return
	_build_track_segments_from_graph(map_graph)
	resource_generator.add_resources_to_map_graph(map_graph)
	_place_train_on_active_route()


func regenerate_map() -> void:
	if map_graph_generator != null:
		map_graph_generator.regenerate_map()


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
		if location.track_segments.size() > 0:
			location.highlight_track_selection()


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


func _resolve_train_marker() -> PathFollow2D:
	if trainMarker == null or not is_instance_valid(trainMarker):
		trainMarker = get_node_or_null("TrainMarker") as PathFollow2D
	return trainMarker


func _detach_train_marker_from_routes() -> void:
	var marker := _resolve_train_marker()
	if marker == null:
		active_track = null
		return

	_clear_route_train_references(marker)

	if marker.get_parent() != self:
		var current_parent := marker.get_parent()
		if current_parent != null:
			current_parent.remove_child(marker)
		add_child(marker)

	active_track = null


func _clear_route_train_references(marker: PathFollow2D) -> void:
	for segment in _track_segments:
		if is_instance_valid(segment) and segment.train_marker == marker:
			segment.train_marker = null
	if mainRoute != null and mainRoute.trainMarker == marker:
		mainRoute.trainMarker = null


func assign_train_to_track(segment: TrackSegment, marker: PathFollow2D) -> void:
	_clear_route_train_references(marker)
	active_track = segment
	segment.add_train(marker)


func assign_train_to_legacy_route(marker: PathFollow2D) -> void:
	if mainRoute == null:
		return
	_clear_route_train_references(marker)
	active_track = null
	mainRoute.add_train(marker)


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

	if map_graph != null:
		var route: Array[MapLocation] = map_graph.get_main_route()
		if route.size() >= 2:
			var segment := _find_segment_between(route[0], route[1])
			if segment != null:
				assign_train_to_track(segment, marker)
				marker.progress_ratio = 0.5
				return

	assign_train_to_legacy_route(marker)
	marker.progress_ratio = 0.5


func _find_segment_between(location_a: MapLocation, location_b: MapLocation) -> TrackSegment:
	for segment in _track_segments:
		if segment.connects(location_a, location_b):
			return segment
	return null

func _update_train_position(progress: float) -> bool:
	var marker := _resolve_train_marker()
	if marker == null:
		return false

	if active_track != null and is_instance_valid(active_track):
		active_track.update_train_pos(progress)
		return true

	if mainRoute == null:
		return false

	if mainRoute.trainMarker == null or not is_instance_valid(mainRoute.trainMarker):
		assign_train_to_legacy_route(marker)

	if mainRoute.trainMarker != null:
		mainRoute.update_trainPos(progress)
		return true

	return false


func select_new_train(newTrain : Train):
	selectedTrain = newTrain


func train_step():
	if not _update_train_position(selectedTrain.speed * local_to_global_speed_conversion):
		return
	sun1.progress -= sunspeed
	sun2.progress -= sunspeed
	update_time_to_sun()
	# Debug testing - Next oil spot
	var nextOil : ResourceSpot = get_next_resource_spot("oil")
	if nextOil != null:
		#nextOil.colorRect.color = Color.RED
		#print("distance to oil well: %f" % get_dist_to_next_resource_spot("oil"))
		#print("Next Oil Well has %s units and is at %f" % [nextOil.quantity, nextOil.progress])
		pass

func request_resources(wantedType : String) -> float:
	return mainRoute.request_resources(wantedType, collection_margin)

func gather_resource(wantedType : String, amount : float) -> int:
	return mainRoute.gather_resource(wantedType, amount, collection_margin)

func query_resource_types() -> Array[ResourceSpot]:
	return mainRoute.query_resources_types(collection_margin)

func get_next_resource_spot(_type : String) -> ResourceSpot:
	return mainRoute.get_next_resource_spot(_type)

func get_dist_to_next_resource_spot(_type : String) -> float:
	return mainRoute.get_dist_to_next_resource_spot(_type)

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
