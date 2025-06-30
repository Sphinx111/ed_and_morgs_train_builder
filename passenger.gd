extends Node2D

class_name Passenger

var manager = null       # Passenger manager script
var parentTrain : Train = null   # Train the passenger is allocated to

var firstname : String = ""
var lastname : String = ""
var movespeed = 30

var home_cabin = null
var destination : Vector2 = self.position

# Foodtypes and last tick they were eaten on (to track food variety)
var foodsEaten = {
	"food1" : 0
}

var targetNeed = "clean_water"
var needs = {
	"clean_water" : 0.75,
	"food" : 0.0,
	"bathroom" : 0.0,
	"fun" : 0.0,
	"social" : 0.0
}

var skills = {
	"strength" : randf() / 2,
	"intelligence" : randf() / 2
}

# Array of recent thoughts
var thoughts : PackedStringArray = []

func _ready():
	manager = get_parent()
	parentTrain = manager.get_parent()

func _process(delta) -> void:
	position = position.move_toward(destination, movespeed * delta)
	pass

func resource_tick():
	for key in needs.keys():
		needs[key] += 0.01
		if needs[key] > 0.8:
			targetNeed = key
			pick_direction()

func pick_direction():
	var myLocation = parentTrain.get_trainpos_from_coords(self.position)
	var distanceToTarget = parentTrain.passengerMap.get_direction_from_to(myLocation, targetNeed)
	myLocation[0] += floor(distanceToTarget / Globals.modules_per_car) 
	myLocation[1] += distanceToTarget % Globals.modules_per_car
	destination = parentTrain.carriages[myLocation[0]].position
	destination.x += (myLocation[1] + 0.5) * Globals.module_width
	if distanceToTarget > 7:
		thoughts.append("It's a long way to " + targetNeed)
		print(thoughts[thoughts.size()-1])
