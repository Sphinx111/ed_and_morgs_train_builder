extends Path2D

## Day/night sun band that loops along the map path using two overlay followers.
class_name MapSun

@export var radius : float = 512.0
@export var localSpeed : float = 150.0
@export var speed : float = localSpeed * Globals.local_to_global_speed_conversion ## Path progress per tick. Positive moves east; negative moves west.
@export var temperature : float = 110.0 ## Peak map temperature when at the centre of the sun band.

var _sun1 : PathFollow2D = null
var _sun2 : PathFollow2D = null
var _half_path_length : float = 1024.0

func _ready() -> void:
	temperature = Globals.train_max_temp
	_sun1 = get_node("Sun1") as PathFollow2D
	_sun2 = get_node("Sun2") as PathFollow2D
	if curve != null and curve.get_point_count() >= 2:
		_half_path_length = curve.get_baked_length() / 2.0
	if _sun2.progress < 1.0:
		_sun2.progress = _half_path_length

func advance() -> void:
	_sun1.progress += speed
	_sun2.progress += speed

func get_sun_height(map_position : Vector2) -> float:
	var map_x : float = map_position.x
	var left_edge : float = _sun1.position.x
	if map_x >= left_edge and map_x < left_edge + radius:
		return (map_x - left_edge) / radius
	left_edge = _sun2.position.x
	if map_x >= left_edge and map_x < left_edge + radius:
		return 1.0 + (map_x - left_edge) / radius
	return -1.0

func is_position_in_sun(map_position : Vector2) -> bool:
	return get_sun_height(map_position) >= 0.0

func get_temperature_at(map_position : Vector2) -> float:
	var height : float = get_sun_height(map_position)
	if height < 0.0:
		return Globals.train_base_temp
	var intensity : float = 1.0 - abs(height - 1.0)
	return lerpf(Globals.train_base_temp, temperature, intensity)

func get_time_until_reaches(map_position : Vector2) -> float:
	if is_position_in_sun(map_position):
		return 0.0
	if is_zero_approx(speed):
		return -1.0
	var distance : float = _distance_until_reaches_x(map_position.x)
	if distance < 0.0:
		return -1.0
	return distance / abs(speed)

func update_time_label(reference_position : Vector2, label : Label) -> void:
	if label == null:
		return
	var time_to_sun : float = get_time_until_reaches(reference_position)
	if time_to_sun >= 0.0:
		label.text = Helpers.seconds_to_mm_ss(time_to_sun)
	else:
		label.text = "N/A"

func _followers() -> Array[PathFollow2D]:
	return [_sun1, _sun2]

func _distance_until_reaches_x(map_x : float) -> float:
	var best_distance : float = -1.0
	for follower in _followers():
		var left_edge : float = follower.position.x
		var right_edge : float = left_edge + radius
		var distance : float = _leading_edge_distance(map_x, left_edge, right_edge)
		if distance <= 0.0:
			continue
		if best_distance < 0.0 or distance < best_distance:
			best_distance = distance
	return best_distance

func _leading_edge_distance(map_x : float, left_edge : float, right_edge : float) -> float:
	if speed > 0.0:
		# Moving east: the right edge leads; time until it reaches map_x from the west.
		if right_edge < map_x:
			return map_x - right_edge
	else:
		# Moving west: the left edge leads; time until it reaches map_x from the east.
		if left_edge > map_x:
			return left_edge - map_x
	return -1.0
