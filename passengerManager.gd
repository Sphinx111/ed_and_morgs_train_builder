extends Node

class_name PassengerManager

var passengers : Array[Passenger] = []
var dying_passengers : Array[Passenger] = []
var expedition_passengers : Array[Passenger] = []         ## Temporary storage for passengers being removed to go on expeditions
var dead : Array[Gravestone] = []

var PassengerScene = preload("res://Scenes/passenger.tscn")
var debugLeft : Line2D = null
var debugRight : Line2D = null

const firstNamesList = ["David", "Elias", "Jenny", "Emma", "Sally", "Uzbel", "Dmitri", "Janus", "Elise", "Marie", "Jonathan", "Bruce", "Eliza"]
const lastNamesList  = ["Smith", "Jones", "LeClair", "McGilligan", "Cuttier", "Founderson", "Embraer", "Einstein", "Damon", "Cruise"]

var available_workers : int = 0
var work_priorities : Array[String]= ["clean_water", "food1", "grey_water", "scrap", "mech_parts", "fuel", "any"]

func _ready():
	for i in range(Globals.passengers_initial_count):
		add_passenger()
	debugLeft = $DebugLeft
	debugRight = $DebugRight

func _process(_delta : float):
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

	for passenger : Passenger in expedition_passengers:
		passengers.erase(passenger)
	expedition_passengers = []

	for passenger in passengers:
		passenger.resource_tick()
		if passenger.is_dying == true:
			dying_passengers.append(passenger)
		if passenger.is_on_expedition == true:
			expedition_passengers.append(passenger)

## Find next work priority in priority order, based on what was last checked
func get_next_work_priority() -> String:
	var result = "any"
	var passengerMap : PassengerMap = get_parent().passengerMap
	for workType in work_priorities:
		if passengerMap.has_work_for_type(workType):
			return workType
	return result

func check_all_needs():
	for passenger in passengers:
		passenger.check_needs()
		passenger.pick_direction()

func add_passenger():
	var newPass = PassengerScene.instantiate()
	add_child(newPass)
	apply_random_name(newPass)
	passengers.append(newPass)

func recover_expedition(returning : Array[Passenger]):
	for passenger in returning:
		passenger.is_on_expedition = false
		passenger.show()
		passengers.append(passenger)

## Select some passengers, mark them as on an expedition, and return an array containing the passenger references
func get_expedition_passengers(count : int) -> Array[Passenger]:
	var result : Array[Passenger] = []
	for i in range(count):
		passengers[i].cleanup()
		passengers[i].is_on_expedition = true
		passengers[i].hide()
		passengers[i].fix_all_needs()
		result.append(passengers[i])
	for passenger in result:
		passengers.erase(passenger)
	return result

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
