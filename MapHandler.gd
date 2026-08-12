extends Node2D

class_name MapHandler

var mainRoute : BranchLine = null          ## The current branch that the train is on
var trainMarker : PathFollow2D = null      ## A visual marker for the train's position on the route
var selectedTrain : Train = null           ## A pointer to the player's train

var collection_margin : float = 40   ## Range at which resources can be collected
var local_to_global_speed_conversion : float = 0.005     # Multiple train's speed value by this to get worldmap pixels per tick

var sun1 : PathFollow2D = null
var sun2 : PathFollow2D = null
var sunradius : float = 512.0
var sun_path_length : float = 2048.0
var map_width : float = 1024.0
var sunspeed : float = 1.0

func _ready():
	mainRoute = get_node("MainRoute")
	trainMarker = get_node("TrainMarker")
	trainMarker.loop = false
	sun1 = get_node("MapMask/Sunpath/Sun1")
	sun2 = get_node("MapMask/Sunpath/Sun2")
	mainRoute.add_train(trainMarker)
	trainMarker.progress_ratio = 0.5

func select_new_train(newTrain : Train):
	selectedTrain = newTrain

func train_step():
	mainRoute.update_trainPos(selectedTrain.speed * local_to_global_speed_conversion)
	sun1.progress -= sunspeed
	sun2.progress -= sunspeed
	update_time_to_sun()
	# Debug testing - Next oil spot
	var nextOil : ResourceSpot = get_next_resource_spot("oil")
	if nextOil != null:
		#nextOil.colorRect.color = Color.RED
		print("distance to oil well: %f" % get_dist_to_next_resource_spot("oil"))
		#print("Next Oil Well has %s units and is at %f" % [nextOil.quantity, nextOil.progress])

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
