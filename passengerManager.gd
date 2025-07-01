extends Node

class_name PassengerManager

var passengers : Array[Passenger] = []
var needs_check_timer : Timer = null

func _ready():
	var firstPassenger : Passenger = find_child("Passenger")
	passengers.append(firstPassenger)
	needs_check_timer = Timer.new()
	add_child(needs_check_timer)
	needs_check_timer.wait_time = 1.0
	needs_check_timer.one_shot = false
	needs_check_timer.timeout.connect(check_all_needs)
	needs_check_timer.start()

func resource_tick():
	for passenger in passengers:
		passenger.resource_tick()

func check_all_needs():
	for passenger in passengers:
		passenger.check_needs()
		passenger.pick_direction()
