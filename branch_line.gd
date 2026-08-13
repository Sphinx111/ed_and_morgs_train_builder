extends Path2D

class_name BranchLine

var resources : Array[ResourceSpot] = []                 ## Array of resource spots
var line : Line2D = null
var trainMarker : PathFollow2D = null
var active : bool = false

@export var next_junction : Junction = null
@export var last_junction : Junction = null
@export var scrap_count : int = 0
@export var pop_count : int = 0
@export var water_count : int = 0
@export var oil_count : int = 0
var scrap_default : int = 200
var pop_default : int = 10
var water_default : int = 300
var oil_default : int = 500

func _ready():
	draw_routes()
	generate_random_resources()

func init_line(origin_point : Vector2):
	position = origin_point

## Move train on by number of pixels
func update_trainPos(progress : float):
	trainMarker.progress = trainMarker.progress - (progress * Globals.train_direction)
	if Globals.train_direction < 0 and trainMarker.progress_ratio >= 1.0: last_junction.transfer_train(trainMarker)
	elif Globals.train_direction > 0 and trainMarker.progress_ratio <= 0.0: next_junction.transfer_train(trainMarker)

## Reparent a train to this branch
func add_train(marker : PathFollow2D):
	trainMarker = marker
	trainMarker.get_parent().remove_child(trainMarker)
	add_child(trainMarker)
	if Globals.train_direction < 0 : trainMarker.progress_ratio = 0.0
	elif Globals.train_direction > 0 : trainMarker.progress_ratio = 1.0

func add_next_junction(newJunction : Junction):
	next_junction = newJunction

func add_last_junction(newJunction : Junction):
	last_junction = newJunction

func draw_routes():
	line = Line2D.new()
	line.default_color = Color(0.4,0.4,0.4, 0.4)
	line.width = 10
	for point in curve.get_baked_points():
		line.add_point(point)
	add_child(line)


func set_active(toggled : bool):
	if toggled:
		line.default_color = Color(0.7, 0.7, 0.7, 0.9)
		active = true
	else:
		line.default_color = Color(0.4, 0.4, 0.4, 0.4)
		active = false
	

func generate_random_resources():
	# Scrap
	for i in range(scrap_count):
		var newSpot = ResourceSpot.new()
		var randPos = randf_range(0.1, 0.9)
		add_child(newSpot)
		newSpot.progress_ratio = randPos
		newSpot.set_stats("scrap", scrap_default)
		resources.append(newSpot)
	for i in range(pop_count):
		var newSpot = ResourceSpot.new()
		var randPos = randf()
		add_child(newSpot)
		newSpot.progress_ratio = randPos
		newSpot.set_stats("pop", randi_range(2,pop_default))
		resources.append(newSpot)
	for i in range(water_count):
		var newSpot = ResourceSpot.new()
		var randPos = randf()
		add_child(newSpot)
		newSpot.progress_ratio = randPos
		newSpot.set_stats("grey_water", water_default)
		resources.append(newSpot)
	for i in range(oil_count):
		var newSpot = ResourceSpot.new()
		var randPos = randf()
		add_child(newSpot)
		newSpot.progress_ratio = randPos
		newSpot.set_stats("oil", oil_default)
		resources.append(newSpot)

func request_resources(wantedType : String, collection_margin : float) -> float:
	for spot in resources:
		if spot.resource_type == wantedType and abs(spot.progress - trainMarker.progress) <= collection_margin: 
			return spot.quantity
	return 0

func gather_resource(wantedType : String, amount : float, collection_margin : float) -> int:
	for spot in resources:
		if abs(spot.progress - trainMarker.progress) <= collection_margin:
			if spot.resource_type == wantedType and spot.quantity >= amount:
				spot.quantity -= amount
				if spot.quantity < 1:
					resources.erase(spot)
					spot.queue_free()
				return Globals.RESULT_OK
	return Globals.NO_RESOURCES

func get_leftmost_xPos() -> float:
	var points = curve.get_baked_points()
	return position.x + (points[0].x * scale.x)

func query_resources_types(collection_margin : float) -> Array[ResourceSpot]:
	var result : Array[ResourceSpot] = []
	for spot in resources:
		if abs(spot.progress - trainMarker.progress) <= collection_margin:
			result.append(spot)
	return result

func get_next_resource_spot(_type : String) -> ResourceSpot:
	var nextBestDistance : float = 99
	var nextSpot : ResourceSpot = null
	for resourceSpot in resources:
		if resourceSpot.resource_type == _type or _type == null:
			var progressDiff : float = trainMarker.progress - resourceSpot.progress
			if Globals.train_direction == -1:
				progressDiff = resourceSpot.progress - trainMarker.progress
			if progressDiff > 0 && progressDiff < nextBestDistance:
				nextBestDistance = progressDiff
				nextSpot = resourceSpot
	return nextSpot

func get_dist_to_next_resource_spot(_type : String) -> float:
	return abs(trainMarker.progress - get_next_resource_spot(_type).progress)
