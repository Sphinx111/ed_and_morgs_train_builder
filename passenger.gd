extends Node2D

class_name Passenger

var manager = null       # Passenger manager script
var parentTrain : Train = null   # Train the passenger is allocated to

var firstname : String = ""
var lastname : String = ""
var movespeed = 30

var current_module : ModuleBase = null
var next_module_pos : float = Globals.module_width		# If position.x exceeds this, check module
var last_module_pos : float = 0.0						# If position.x falls below this, check module
var direction : int = 0

var home_cabin = null
var destination : Vector2 = self.position
var is_in_module : bool = false

# Foodtypes and last tick they were eaten on (to track food variety)
var foodsEaten = {
	"food1" : 0
}

var targetNeed = ""
var needs = {
	"thirst" : 0.0,
	"hunger" : 0.78,
	"rest" : 0.0
}
const maxNeeds = {
	"thirst" : 1.0,
	"hunger" : 1.0,
	"rest" : 2.0
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
	if is_in_module == false:
		destination.x = max(destination.x, parentTrain.minXpos)
		destination.x = min(destination.x, parentTrain.maxXpos)
		position = position.move_toward(destination, movespeed * delta)
		if (direction > 0 and position.x > next_module_pos) or (direction < 0 and position.x < last_module_pos):
			update_module_positions()

# Once at outset, or per module moved, confirm position on train and which module we are at
# set thresholds to re-check module next
func update_module_positions():
	var myLocation = parentTrain.get_trainpos_from_coords(self.position)
	last_module_pos = parentTrain.get_xpos_from_trainpos(myLocation)
	current_module = parentTrain.carriages[myLocation[0]].modules[myLocation[1]]
	var nextLocation = myLocation
	nextLocation[1] = nextLocation[1] + 1
	if nextLocation[1] == Globals.modules_per_car:
		nextLocation[0] = nextLocation[0] + 1
		nextLocation[1] = 0
	next_module_pos = parentTrain.get_xpos_from_trainpos(nextLocation)
	check_current_module()


# If my needs have just changed, check whether the module I am in serves what I need
func check_current_module():
	var myLocation = parentTrain.get_trainpos_from_coords(self.position)
	current_module = parentTrain.carriages[myLocation[0]].modules[myLocation[1]]
	if current_module.can_serve_need(targetNeed):
		enter_customer_module(current_module, 1)


func enter_customer_module(target : ModuleBase, attemptNo : int):
	if target.can_enter(self):
		target.add_customer(self)
		self.hide()
		is_in_module = true

func exit_customer_module():
	self.show()
	targetNeed = ""
	is_in_module = false

func resource_tick():
	for key in needs.keys():
		needs[key] += 0.01
	check_needs()

func check_needs():
	var maxVal : float = 0.0
	var maxNeed : String = ""
	for key in needs.keys():
		if needs[key] > maxVal:
			maxNeed = key
			maxVal = needs[key]
			if maxVal >= maxNeeds[key]:
				hit_max_need(key)
	if maxVal > Globals.passenger_seeks_threshold:
		if maxNeed != "" and maxNeed != targetNeed:
			targetNeed = maxNeed
			check_current_module()

func hit_max_need(needType : String):
	print("%s %s: Oh no! My %s need hit max, I'm gonna die now" % [firstname, lastname, needType])
	manager.remove_passenger(self)

func pick_direction():
	# Chance to idly move around if no behaviour
	if targetNeed == "":
		if randf() < Globals.idle_wander_chance:
			destination = self.position
			var offset : float = randi_range(-200, 200)
			if offset >= 0: direction = 1
			else: direction = -1
			destination.x += offset
		return	# End early if no target
	
	var myLocation = parentTrain.get_trainpos_from_coords(self.position)
	var distanceToTarget = parentTrain.passengerMap.get_direction_from_to(myLocation, targetNeed)
	if distanceToTarget == 9999:
		thoughts.append("This train has no way to help with %s" % targetNeed)
		return
	if    distanceToTarget > 0: direction = 1
	elif  distanceToTarget < 0: direction = -1
	else: direction = 0
	myLocation[0] += floor(distanceToTarget / Globals.modules_per_car) 
	myLocation[1] += distanceToTarget % Globals.modules_per_car
	destination = parentTrain.carriages[myLocation[0]].position
	destination.x += (myLocation[1] + 0.5) * Globals.module_width
	
	if distanceToTarget > 7:
		thoughts.append("It's a long way to " + targetNeed)
		print(thoughts[thoughts.size()-1])

# adjust the need, and return the amount remaining
func adjust_need(type : String, amount : float) -> float:
	needs[type] = max(needs[type] - amount, 0)
	return needs[type]
