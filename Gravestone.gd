extends Node
## A simple data object to hold data about a dead passenger

class_name Gravestone

var firstname : String = ""
var lastname : String = ""
var age : int = 0
var cause_of_death : String = ""
var tick_died : int = 0

func create_gravestone(person : Passenger):
	firstname = person.firstname
	lastname = person.lastname
	age = randi_range(10,75)
	cause_of_death = person.targetNeed
	tick_died = Globals.game_tick
