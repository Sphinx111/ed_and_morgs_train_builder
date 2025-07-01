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

func _process(delta) -> void:
	destination.x = max(destination.x, parentTrain.minXpos)
	destination.x = min(destination.x, parentTrain.maxXpos)
	position = position.move_toward(destination, movespeed * delta)
	if (direction > 0 and position.x > next_module_pos) or (direction < 0 and position.x < last_module_pos):
		recheck_module()
	pass

# Once at outset, or per module moved, confirm position on train and which module we are at
# set thresholds to re-check module next
func recheck_module():
	var myLocation = parentTrain.get_trainpos_from_coords(self.position)
	current_module = parentTrain.carriages[myLocation[0]].modules[myLocation[1]]
	
	# If we move left of this point, we have left current module and need to check
	last_module_pos = current_module.position.x
	if myLocation[1] == 0:
		last_module_pos -= Globals.car_separation

	# Get thresholds to check next module (moving right)
	next_module_pos = position.x + Globals.module_width
	if myLocation[1] == 3:
		next_module_pos += Globals.car_separation
	
	if current_module.can_serve_need(targetNeed):
		enter_customer_module(current_module, 1)
	print("I'm at the " + current_module.type + " module!")

func enter_customer_module(target : ModuleBase, attemptNo : int):
	if target.can_enter(self):
		target.add_customer(self)
		self.hide()
	else:
		destination.x += randi_range(-Globals.module_width/4, Globals.module_width/4)    # Wait in random spot outside module

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
		recheck_module()

func pick_direction():
	# Chance to idly move around if no behaviour
	if targetNeed == "" and randf() < Globals.idle_wander_chance:
		destination = self.position
		var offset : float = randi_range(-200, 200)
		if offset >= 0: direction = 1
		else: direction = -1
		destination.x += offset
		return	# End early if no target
	
	var myLocation = parentTrain.get_trainpos_from_coords(self.position)
	var distanceToTarget = parentTrain.passengerMap.get_direction_from_to(myLocation, targetNeed)
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
