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

var debugLeft : Line2D = null
var debugRight : Line2D = null

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

var skills = {
	"strength" : randf() / 2,
	"intelligence" : randf() / 2
}

# Array of recent thoughts
var thoughts : PackedStringArray = []

func _ready():
	manager = get_parent()
	parentTrain = manager.get_parent()
	debugLeft = $DebugLeft
	debugRight = $DebugRight

func _process(delta) -> void:
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
	
	myLocation[1] = myLocation[1] + 1
	if myLocation[1] == Globals.modules_per_car:
		myLocation[0] = myLocation[0] + 1
		myLocation[1] = 0
	next_module_pos = parentTrain.get_xpos_from_trainpos(myLocation)
	print("next module: %f" % next_module_pos)
	
	debugLeft.position.x = last_module_pos# - position.x
	debugRight.position.x = next_module_pos# - position.x


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

func exit_customer_module():
	self.show()
	targetNeed = ""

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
	if maxVal > Globals.passenger_seeks_threshold:
		#if maxNeed != "" and maxNeed != targetNeed:
		targetNeed = maxNeed
		check_current_module()

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
