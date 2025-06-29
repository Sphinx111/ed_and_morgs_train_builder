extends Node2D

class_name Passenger

var manager = null       # Passenger manager script
var parentTrain = null   # Train the passenger is allocated to

var firstname : String = ""
var lastname : String = ""

var home_cabin = null
var destination = null

# Foodtypes and last tick they were eaten on (to track food variety)
var foodsEaten = {
	"food1" : 0
}

var needs = {
	"water" : 0.0,
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
