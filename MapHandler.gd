extends Node2D

class_name MapHandler

@onready
var mainRoute : Path2D = null
var trainMarker : PathFollow2D = null
var selectedTrain : Train = null

var step_percent : float = 0.0025
var resources : Array[ResourceSpot] = []
var collection_margin : float = step_percent * 4

func _ready():
	mainRoute = find_child("MainRoute")
	trainMarker = mainRoute.find_child("TrainMarker")
	trainMarker.loop = true
	selectedTrain =  get_parent().selectedTrain
	resources.append(find_child("ResourceSpot"))
	
	generate_random_resources(4)
	draw_routes()

func draw_routes():
	var l := Line2D.new()
	l.default_color = Color(0.7,0.7,0.7, 1)
	l.width = 2
	for point in mainRoute.curve.get_baked_points():
		l.add_point(point+mainRoute.position)
	mainRoute.add_child(l)

func generate_random_resources(count : int):
	for i in range(count):
		var newSpot = ResourceSpot.new()
		var randPos = randf()
		mainRoute.add_child(newSpot)
		newSpot.progress_ratio = randPos
		resources.append(newSpot)

func update_trainPos(progress : float):
	trainMarker.progress_ratio = progress

func train_step():
	trainMarker.progress_ratio += step_percent

func request_resources(wantedType : String) -> float:
	for spot in resources:
		if spot.resource_type == wantedType and abs(spot.progress_ratio - trainMarker.progress_ratio) <= collection_margin: 
			return spot.quantity
	return 0

func gather_resource(wantedType : String, amount : float) -> int:
	for spot in resources:
		if spot.resource_type == wantedType and abs(spot.progress_ratio - trainMarker.progress_ratio) <= collection_margin: 
			if spot.quantity >= amount:
				spot.quantity -= amount
				return Globals.RESULT_OK
	return Globals.NO_RESOURCES
