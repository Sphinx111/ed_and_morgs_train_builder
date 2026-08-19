extends PathFollow2D

## Controls the train icon's position along the active TrackSegment.
class_name TrainMarker

var map_handler: MapHandler = null
var current_track: TrackSegment = null
## When true the train is moving toward end_location on the current segment.
var travel_toward_end: bool = true


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

	if _progress_ratio >= 0.0:
		self.progress_ratio = _progress_ratio
	elif from_node != null:
		self.progress_ratio = 0.0 if segment.start_location == from_node else 1.0
	elif Globals.train_direction < 0:
		self.progress_ratio = 0.0
	elif Globals.train_direction > 0:
		self.progress_ratio = 1.0
	else:
		self.progress_ratio = 0.5

	_update_travel_direction()


func _update_travel_direction() -> void:
	if current_track == null:
		return
	if Globals.train_direction < 0:
		travel_toward_end = true
	elif Globals.train_direction > 0:
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
	if current_track == null or current_track.curve == null:
		return null
	var track_length := current_track.curve.get_baked_length()
	if travel_toward_end and progress >= track_length - _range:
		return current_track.end_location
	if not travel_toward_end and progress <= _range:
		return current_track.start_location
	return null


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
