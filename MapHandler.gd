extends Node2D

class_name MapHandler

var mainRoute : BranchLine = null          ## The current branch that the train is on
var trainMarker : PathFollow2D = null      ## A visual marker for the train's position on the route
var selectedTrain : Train = null           ## A pointer to the player's train

var collection_margin : float = 5   ## Range at which resources can be collected
var local_to_global_speed_conversion : float = 0.001     # Multiple train's speed value by this to get worldmap pixels per tick

func _ready():
	mainRoute = find_child("MainRoute")
	trainMarker = find_child("TrainMarker")
	trainMarker.loop = false
	mainRoute.add_train(trainMarker)

func select_new_train(newTrain : Train):
	selectedTrain = newTrain

func train_step():
	mainRoute.update_trainPos(selectedTrain.res["speed"] * local_to_global_speed_conversion)

func request_resources(wantedType : String) -> float:
	return mainRoute.request_resources(wantedType, collection_margin)

func gather_resource(wantedType : String, amount : float) -> int:
	return mainRoute.gather_resources(wantedType, amount, collection_margin)
