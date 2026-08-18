extends PathFollow2D

## Controls the train icon's position along the active TrackSegment.
class_name TrainMarker

var map_handler: MapHandler = null
var current_track: TrackSegment = null
## When true the train is moving toward end_location on the current segment.
var travel_toward_end: bool = true


func enter_track(segment: TrackSegment, progress_ratio: float = -1.0) -> void:
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

	if progress_ratio >= 0.0:
		self.progress_ratio = progress_ratio
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
	if travel_toward_end:
		return current_track.end_location
	return current_track.start_location


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

	progress = progress - (progress_delta * Globals.train_direction)
	_check_segment_end()


func _check_segment_end() -> void:
	if current_track == null:
		return

	var from_segment: TrackSegment = current_track
	if Globals.train_direction < 0 and progress_ratio >= 1.0:
		current_track.end_location.transfer_train(self, from_segment)
	elif Globals.train_direction > 0 and progress_ratio <= 0.0:
		current_track.start_location.transfer_train(self, from_segment)


func is_on_track() -> bool:
	return current_track != null and is_instance_valid(current_track) and get_parent() == current_track
