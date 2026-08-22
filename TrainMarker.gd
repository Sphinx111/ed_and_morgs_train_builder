extends PathFollow2D

## Controls the train icon's position along the active TrackSegment.
class_name TrainMarker

var map_handler: MapHandler = null
var current_track: TrackSegment = null
## When true the train is moving toward end_location on the current segment.
var travel_toward_end: bool = true


static func travels_toward_end_on_map() -> bool:
	return Globals.train_direction > 0


func enter_track(
	segment: TrackSegment,
	_progress_ratio: float = -1.0,
	from_node: MapLocation = null
) -> void:
	current_track = segment
	if segment == null:
		return

	if get_parent() != segment:
		if get_parent() != null:
			reparent(segment)
		else:
			segment.add_child(self)

	if segment.curve == null or segment.curve.get_point_count() < 2:
		return

	if from_node != null:
		_apply_entry_at_node(segment, from_node)
	elif _progress_ratio >= 0.0:
		self.progress_ratio = _progress_ratio
		_update_travel_direction_from_map()
	elif travels_toward_end_on_map():
		self.progress_ratio = 0.0
		_update_travel_direction_from_map()
	elif Globals.train_direction < 0:
		self.progress_ratio = 1.0
		_update_travel_direction_from_map()
	else:
		self.progress_ratio = 0.5
		_update_travel_direction_from_map()


func _apply_entry_at_node(segment: TrackSegment, from_node: MapLocation) -> void:
	if segment.start_location == from_node:
		progress_ratio = 0.0
		travel_toward_end = true
	elif segment.end_location == from_node:
		progress_ratio = 1.0
		travel_toward_end = false
	else:
		push_warning("TrainMarker: entry node is not connected to segment")
		progress_ratio = 0.5
		_update_travel_direction_from_map()


func _update_travel_direction_from_map() -> void:
	if current_track == null:
		return
	if travels_toward_end_on_map():
		travel_toward_end = true
	elif Globals.train_direction < 0:
		travel_toward_end = false
	else:
		travel_toward_end = progress_ratio <= 0.5


func get_travel_exit_node() -> MapLocation:
	if current_track == null:
		return null
	return current_track.get_node_ahead(travel_toward_end)


func get_travel_entry_node() -> MapLocation:
	if current_track == null:
		return null
	return current_track.get_node_behind(travel_toward_end)


func get_distance_remaining_on_segment() -> float:
	if current_track == null or current_track.curve == null:
		return 0.0
	var track_length := current_track.curve.get_baked_length()
	if travel_toward_end:
		return track_length - progress
	return progress


func get_nearby_node(_range: float) -> MapLocation:
	var nearby_nodes := get_nearby_nodes(_range)
	if nearby_nodes.is_empty():
		return null
	if nearby_nodes.size() == 1:
		return nearby_nodes[0]
	return _get_closest_nearby_node(nearby_nodes)


func get_nearby_nodes(_range: float) -> Array[MapLocation]:
	var result: Array[MapLocation] = []
	if current_track == null or current_track.curve == null:
		return result
	var track_length := current_track.curve.get_baked_length()
	if progress <= _range:
		result.append(current_track.start_location)
	if progress >= track_length - _range:
		result.append(current_track.end_location)
	return result


func _get_closest_nearby_node(nearby_nodes: Array[MapLocation]) -> MapLocation:
	var closest_node: MapLocation = nearby_nodes[0]
	var closest_distance := _distance_to_location(closest_node)
	for i in range(1, nearby_nodes.size()):
		var candidate := nearby_nodes[i]
		var candidate_distance := _distance_to_location(candidate)
		if candidate_distance < closest_distance:
			closest_node = candidate
			closest_distance = candidate_distance
	return closest_node


func _distance_to_location(location: MapLocation) -> float:
	if current_track == null or current_track.curve == null:
		return INF
	var track_length := current_track.curve.get_baked_length()
	if location == current_track.start_location:
		return progress
	if location == current_track.end_location:
		return track_length - progress
	return INF


func detach_to(holder: Node) -> void:
	current_track = null
	if holder == null:
		return
	if get_parent() != holder:
		if get_parent() != null:
			reparent(holder)
		else:
			holder.add_child(self)


func advance(progress_delta: float) -> void:
	if current_track == null:
		return

	if travel_toward_end:
		progress += progress_delta
	else:
		progress -= progress_delta
	_check_segment_end()


func _check_segment_end() -> void:
	if current_track == null:
		return

	var from_segment: TrackSegment = current_track
	if travel_toward_end and progress_ratio >= 1.0:
		current_track.end_location.transfer_train(self, from_segment)
	elif not travel_toward_end and progress_ratio <= 0.0:
		current_track.start_location.transfer_train(self, from_segment)


func is_on_track() -> bool:
	return current_track != null and is_instance_valid(current_track) and get_parent() == current_track
