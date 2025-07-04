extends Node

class_name PassengerManager

var passengers : Array[Passenger] = []
var needs_check_timer : Timer = null

var PassengerScene = preload("res://Scenes/passenger.tscn")
var debugLeft : Line2D = null
var debugRight : Line2D = null

const firstNamesList = ["David", "Elias", "Jenny", "Emma", "Sally", "Uzbel", "Dmitri", "Janus", "Elise", "Marie"]
const lastNamesList  = ["Smith", "Jones", "LeClair", "McGilligan", "Cuttier", "Founderson"]

func _ready():
	var firstPassenger : Passenger = find_child("Passenger")
	passengers.append(firstPassenger)
	apply_random_name(firstPassenger)
	needs_check_timer = Timer.new()
	add_child(needs_check_timer)
	needs_check_timer.wait_time = 1.0
	needs_check_timer.one_shot = false
	needs_check_timer.timeout.connect(check_all_needs)
	needs_check_timer.start()
	debugLeft = $DebugLeft
	debugRight = $DebugRight

func _process(delta : float):
	if passengers.size() > 0:
		debugLeft.position.x = passengers[0].last_module_pos
		debugRight.position.x = passengers[0].next_module_pos

func resource_tick():
	for passenger in passengers:
		passenger.resource_tick()

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
	

func remove_passenger(passToRemove : Passenger):
	passengers.erase(passToRemove)
	passToRemove.queue_free()
