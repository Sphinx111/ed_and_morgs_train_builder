extends Node

class_name PassengerManager

var passengers : Array[Passenger] = []
var dying_passengers : Array[Passenger] = []
var dead : Array[Gravestone] = []

var PassengerScene = preload("res://Scenes/passenger.tscn")
var debugLeft : Line2D = null
var debugRight : Line2D = null

const firstNamesList = ["David", "Elias", "Jenny", "Emma", "Sally", "Uzbel", "Dmitri", "Janus", "Elise", "Marie"]
const lastNamesList  = ["Smith", "Jones", "LeClair", "McGilligan", "Cuttier", "Founderson"]

func _ready():
	var firstPassenger : Passenger = find_child("Passenger")
	passengers.append(firstPassenger)
	apply_random_name(firstPassenger)
	debugLeft = $DebugLeft
	debugRight = $DebugRight

func _process(delta : float):
	if passengers.size() > 0:
		debugLeft.position.x = passengers[0].last_module_pos
		debugRight.position.x = passengers[0].next_module_pos

func resource_tick():
	# Tidyup all dying passengers first
	for passenger : Passenger in dying_passengers:
		passenger.cleanup()
		passengers.erase(passenger)
		var newgrave = Gravestone.new()
		newgrave.create_gravestone(passenger)
		dead.append(newgrave)
		passenger.queue_free()
	dying_passengers = []

	for passenger in passengers:
		passenger.resource_tick()
		if passenger.is_dying == true:
			dying_passengers.append(passenger)

func check_all_needs():
	for passenger in passengers:
		passenger.check_needs()
		passenger.pick_direction()

func add_passenger():
	var newPass = PassengerScene.instantiate()
	add_child(newPass)
	apply_random_name(newPass)
	passengers.append(newPass)

func apply_random_name(passenger) -> void:
	var constrainedNamesList = []
	passenger.lastname = lastNamesList[randi_range(0, lastNamesList.size()-1)]
	
	#randomise odds of an aliterating name
	if randf() < Globals.aliterating_name_chance:
		constrainedNamesList = firstNamesList.filter(func (string): return string.begins_with(passenger.lastname.left(1)))
		if constrainedNamesList.size() == 0:
			constrainedNamesList = firstNamesList
	else: 
		constrainedNamesList = firstNamesList
	passenger.firstname = constrainedNamesList[randi_range(0, constrainedNamesList.size()-1)]
