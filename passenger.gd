extends Node2D

class_name Passenger

var manager = null       # Passenger manager script
var parentTrain : Train = null   # Train the passenger is allocated to

var firstname : String = ""
var lastname : String = ""
var movespeed = 30

var current_module_pos : float = 0
var current_module : ModuleBase = null
var next_module_pos : float = Globals.module_width

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
	"social" : 0.0,
	"rest" : 0.0
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
	if position.x >= next_module_pos:
		recheck_module()
	pass

func recheck_module():
	current_module_pos = position.x
	next_module_pos = position.x + Globals.module_width
	var myLocation = parentTrain.get_trainpos_from_coords(self.position)
	if myLocation[1] == 3:
		next_module_pos += Globals.car_separation
	current_module = parentTrain.carriages[myLocation[0]].modules[myLocation[1]]
	var mod_serves_need : String = current_module.serves_need
	if needs[mod_serves_need] > Globals.passenger_consume_threshold:
		receive_service(current_module.get_service())
	print("I'm at the " + current_module.type + " module!")

func receive_service(serviceReceived : Array):
	var type : String = serviceReceived[0]
	var amount : float = serviceReceived[1]
	needs[type] -= amount
	if needs[type] < 0:
		needs[type] = 0

func resource_tick():
	for key in needs.keys():
		needs[key] += 0.01
		if needs[key] > Globals.passenger_seeks_threshold:
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
