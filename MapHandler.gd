extends Node2D

class_name MapHandler

var mainRoute : BranchLine = null          ## The current branch that the train is on
var trainMarker : PathFollow2D = null      ## A visual marker for the train's position on the route
var selectedTrain : Train = null           ## A pointer to the player's train

var collection_margin : float = 0.01   ## Range at which resources can be collected
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
	sun1.progress -= sunspeed * Globals.time_factor
	sun2.progress -= sunspeed * Globals.time_factor

func request_resources(wantedType : String) -> float:
	return mainRoute.request_resources(wantedType, collection_margin)

func gather_resource(wantedType : String, amount : float) -> int:
	return mainRoute.gather_resource(wantedType, amount, collection_margin)

func is_train_in_sun() -> bool:
	#print("trainPos: %f sun1pos: %f sun2pos: %f" % [trainMarker.position.x, sun1.position.x, sun2.position.x])
	if trainMarker.position.x > sun1.position.x and trainMarker.position.x < sun1.position.x + sunradius:
		print("train is in sunlight")
		return true
	elif trainMarker.position.x > sun2.position.x and trainMarker.position.x < sun2.position.x + sunradius:
		print("train is in sunlight")
		return true
	return false
