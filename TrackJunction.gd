extends RefCounted

## Track selection and switching at a MapLocation junction.
class_name TrackJunction

var location: MapLocation
var selector_index: int = 0
var last_changed_tick: int = 0
var tick_cooldown: int = 2


func _init(owner: MapLocation) -> void:
	location = owner


func get_selected_segment() -> TrackSegment:
	if location.track_segments.is_empty():
		return null
	return location.track_segments[selector_index]


func register_segment(segment: TrackSegment) -> void:
	if not location.track_segments.has(segment):
		location.track_segments.append(segment)


func sort_segments_clockwise() -> void:
	var segments := location.track_segments
	if segments.size() <= 1:
		return

	var anchor_segment: TrackSegment = segments[0]
	var selected_segment: TrackSegment = get_selected_segment()
	var anchor_angle := _segment_angle(anchor_segment)

	var remaining_segments: Array[TrackSegment] = []
	for index in range(1, segments.size()):
		remaining_segments.append(segments[index])

	remaining_segments.sort_custom(
		func(segment_a: TrackSegment, segment_b: TrackSegment) -> bool:
			var delta_a := _clockwise_angle_delta(anchor_angle, _segment_angle(segment_a))
			var delta_b := _clockwise_angle_delta(anchor_angle, _segment_angle(segment_b))
			return delta_a < delta_b
	)

	segments.clear()
	segments.append(anchor_segment)
	segments.append_array(remaining_segments)

	if selected_segment != null:
		var selected_index := segments.find(selected_segment)
		if selected_index >= 0:
			selector_index = selected_index


## Route building: honour manual selection, otherwise prefer trunk.
func pick_outgoing(from_segment: TrackSegment, travel_toward_end: bool) -> TrackSegment:
	var compatible_segments := _compatible_outgoing(from_segment, travel_toward_end)
	if compatible_segments.is_empty():
		return null

	var selected := get_selected_segment()
	if (
		selected != null
		and selected != from_segment
		and selected.is_entry_compatible(location, travel_toward_end)
	):
		return selected

	return _apply_selection(_pick_best_outgoing(compatible_segments))


## Player input: step clockwise, skipping segments already on the active route.
func cycle_manual() -> void:
	var segments := location.track_segments
	if segments.is_empty():
		return

	var start_index := selector_index
	var attempts := 0
	while attempts < segments.size():
		selector_index = (selector_index + 1) % segments.size()
		attempts += 1
		var segment := get_selected_segment()
		if segment != null and not segment.active:
			return

	selector_index = start_index


func can_switch() -> bool:
	if Globals.game_tick < (last_changed_tick + tick_cooldown):
		return false
	return location.track_segments.size() >= 2


func mark_switched() -> void:
	last_changed_tick = Globals.game_tick


func _apply_selection(segment: TrackSegment) -> TrackSegment:
	if segment == null:
		return null
	var selected_index := location.track_segments.find(segment)
	if selected_index >= 0:
		selector_index = selected_index
	return segment


func _compatible_outgoing(
	from_segment: TrackSegment,
	travel_toward_end: bool
) -> Array[TrackSegment]:
	var compatible_segments: Array[TrackSegment] = []
	for segment in location.track_segments:
		if segment == from_segment:
			continue
		if segment.is_entry_compatible(location, travel_toward_end):
			compatible_segments.append(segment)
	return compatible_segments


func _pick_best_outgoing(candidates: Array[TrackSegment]) -> TrackSegment:
	var best_segment: TrackSegment = null
	var best_rank: int = 999
	for segment in candidates:
		var rank := _edge_rank(segment)
		if best_segment == null or rank < best_rank:
			best_segment = segment
			best_rank = rank
	return best_segment


func _edge_rank(segment: TrackSegment) -> int:
	if segment == null or segment.map_edge == null:
		return 2
	match segment.map_edge.type:
		MapGraphEdge.EdgeType.TRUNK:
			return 0
		MapGraphEdge.EdgeType.BRANCH:
			return 1
		_:
			return 2


func _segment_angle(segment: TrackSegment) -> float:
	var other_node := segment.get_other_node(location)
	if other_node == null:
		return 0.0
	return (other_node.position - location.position).angle()


func _clockwise_angle_delta(from_angle: float, to_angle: float) -> float:
	var delta := fmod(to_angle - from_angle, TAU)
	if delta < 0.0:
		delta += TAU
	return delta
