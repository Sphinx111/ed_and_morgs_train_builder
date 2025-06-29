extends Node

class_name PassengerManager

var passengers : Array[Passenger] = []

func _ready():
	var firstPassenger : Passenger = find_child("Passenger")
	passengers.append(firstPassenger)

func resource_tick():
	for passenger in passengers:
		passenger.resource_tick()
