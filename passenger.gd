extends Node2D

class_name Passenger

var manager : PassengerManager = null       # Passenger manager script
var parentTrain : Train = null   # Train the passenger is allocated to

var firstname : String = ""
var lastname : String = ""
var movespeed = 30
var is_dying : bool = false

var current_module : ModuleBase = null
var next_module_pos : float = Globals.module_width		# If position.x exceeds this, check module
var last_module_pos : float = 0.0						# If position.x falls below this, check module
var direction : int = 0

var home_cabin = null
var destination : Vector2 = self.position
var is_in_module : bool = false
var is_working : bool = false

# Foodtypes and last tick they were eaten on (to track food variety)
var foodsEaten = {
	"food1" : 0
}

var displayNeeds : bool = false
var displayNeedsScene : PackedScene = preload("res://Scenes/passenger_panel.tscn")
var passengerPanel : PassengerPanel = null
var targetNeed = ""
var needs = {
	"thirst" : 0.0,
	"hunger" : 0.65,
	"rest" : 0.0,
	"illness" : 0.0,
	"social" : 0.0
}
const maxNeeds = {
	"thirst" : 1.0,
	"hunger" : 1.0,
	"rest" : 2.0,
	"illness" : 1.0,
	"social" : 1.0
}

var targetWork : String = ""
var skills = {
	"strength" : randf() / 2,
	"intelligence" : randf() / 2
}

# Array of recent thoughts
var thoughts : PackedStringArray = []

func _ready():
	manager = get_parent()
	parentTrain = manager.get_parent()
	_ready_debug_displays()
	_init_random_needs()

func _ready_debug_displays():
	if Globals.passenger_debug == true:
		$DebugThirst.show()
		$DebugHunger.show()
		$DebugRest.show()

func _init_random_needs():
	for key in needs:
		needs[key] = randf_range(0.0, 0.5)

func _process(delta) -> void:
	if is_in_module == false:
		destination.x = max(destination.x, parentTrain.minXpos)
		destination.x = min(destination.x, parentTrain.maxXpos)
		position = position.move_toward(destination, movespeed * delta * Globals.time_factor)
		if position.x < parentTrain.minXpos:
			position.x = parentTrain.minXpos
		if position.x > parentTrain.maxXpos:
			position.x = parentTrain.maxXpos
		if (direction > 0 and position.x > next_module_pos) or (direction < 0 and position.x < last_module_pos):
			update_module_positions()

# Once at outset, or per module moved, confirm position on train and which module we are at
# set thresholds to re-check module next
func update_module_positions():
	var myLocation = Helpers.get_trainpos_from_coords(self.position)
	last_module_pos = Helpers.get_xpos_from_trainpos(myLocation)
	current_module = parentTrain.carriages[myLocation[0]].modules[myLocation[1]]
	var nextLocation = myLocation
	nextLocation[1] = nextLocation[1] + 1
	if nextLocation[1] == Globals.modules_per_car:
		nextLocation[0] = nextLocation[0] + 1
		nextLocation[1] = 0
	next_module_pos = Helpers.get_xpos_from_trainpos(nextLocation)
	check_current_module()

func update_needs_debug():
	$DebugThirst.size.y = (20 * needs["thirst"])
	$DebugHunger.size.y = (20 * needs["hunger"])
	$DebugRest.size.y   = (20 * needs["rest"])

# If my needs have just changed, check whether the module I am in serves what I need
func check_current_module():
	var myLocation = Helpers.get_trainpos_from_coords(self.position)
	current_module = parentTrain.carriages[myLocation[0]].modules[myLocation[1]]
	if targetNeed != "":
		if current_module.can_serve_need(targetNeed):
			enter_customer_module(current_module, 1)
	elif targetWork != "":
		if current_module.needs_worker(targetWork):
			enter_worker_module(current_module, 1)

func enter_customer_module(target : ModuleBase, attemptNo : int):
	if target.can_enter(self):
		if self.is_in_module==false:
			target.add_customer(self)
			self.position.y = Globals.car_height
			is_in_module = true
			
			if passengerPanel != null:
				passengerPanel.actionLabel.text = "being served"
			#current_module = target

func enter_worker_module(target : ModuleBase, attemptNo : int):
	if self.is_in_module==false:
		if target.worker_can_enter(self):
			target.add_worker(self)
			self.position.y = Globals.car_height
			if passengerPanel != null:
				passengerPanel.actionLabel.text = "working"
			is_in_module = true
			is_working = true
			#current_module = target

## Used by passenger to tell module they're leaving
func exit_customer_module():
	ejected_from_module()
	current_module.notify_remove_customer(self)

## Used by modules to eject a passenger
func ejected_from_module():
	self.position.y = 0
	targetNeed = ""
	is_in_module = false
	is_working = false

## Used by passenger to tell module they're leaving
func exit_worker_module():
	self.position.y = 0
	targetWork = ""
	is_in_module = false
	is_working = false
	current_module.remove_worker(self)

## Used by modules to eject a worker
func worker_ejected_from_module():
	self.position.y = 0
	targetWork = ""
	is_in_module = false
	is_working = false

func resource_tick():
	for key in needs.keys():
		needs[key] += Globals.need_growth_rates[key]
	check_needs()
	
	check_for_work()
	if Globals.passenger_debug == true:
		update_needs_debug()
	pick_direction()
	if passengerPanel != null:
		passengerPanel.update_step()

func wants_need(type : String) -> float:
	if needs.has(type):
		return (1.0 - needs[type])
	return 0.0

## Called to remove itself from any modules, this passenger is about to die
func cleanup():
	if is_working and is_in_module:
		current_module.remove_worker(self)
	elif is_in_module:
		current_module.notify_remove_customer(self)

func check_needs():
	var maxVal : float = 0.0
	var maxNeed : String = ""
	for key in needs.keys():
		if needs[key] > maxVal:
			maxNeed = key
			maxVal = needs[key]
			if maxVal >= maxNeeds[key]:
				if hit_max_need(key) == Globals.RESULT_FATAL:
					is_dying = true
					return
	if maxVal > Globals.passenger_seeks_threshold:
		if maxNeed != "" and maxNeed != targetNeed:
			targetNeed = maxNeed
			check_current_module()
			if is_working and is_in_module:
				exit_worker_module()

func check_for_work():
	targetWork = manager.get_next_work_priority()
	check_current_module()

## Allows different results from hitting max need. Not all needs will be fatal
func hit_max_need(needType : String) -> int:
	print("%s %s: Oh no! I am dying of %s" % [firstname, lastname, needType])
	return Globals.RESULT_FATAL

func pick_idle_move():
	if randf() < Globals.idle_wander_chance:
		destination = self.position
		var offset : float = randi_range(-200, 200)
		if offset >= 0: direction = 1
		else: direction = -1
		destination.x += offset
		constrain_destination()

func constrain_destination():
	clamp(destination.x, parentTrain.minXpos, parentTrain.maxXpos)

func pick_direction():
	# Chance to idly move around if no behaviour
	if targetNeed == "" and targetWork == "":
		pick_idle_move()
		return	# End early if no target
	
	var myLocation : Array[int] = Helpers.get_trainpos_from_coords(self.position)
	var distanceToTarget = 0
	if targetNeed != "":
		distanceToTarget = parentTrain.passengerMap.get_direction_from_to(myLocation, targetNeed, "need")
	elif targetWork != "":
		distanceToTarget= parentTrain.passengerMap.get_direction_from_to(myLocation, targetWork, "work")
	
	if distanceToTarget == 9999:
		if targetNeed != "": new_thought("I can't find anywhere to fulfil my crushing %s need!" % [targetNeed])
		pick_idle_move()
		return
	if    distanceToTarget > 0: direction = 1
	elif  distanceToTarget < 0: direction = -1
	else: direction = 0
	if Globals.train_direction > 0:
		direction = direction * -1
	myLocation[0] += floor(distanceToTarget / Globals.modules_per_car) 
	myLocation[1] += distanceToTarget % Globals.modules_per_car
	destination.x = Helpers.get_xpos_from_trainpos(myLocation)
	if Globals.train_direction < 0: destination.x += 0.5 * Globals.module_width
	elif Globals.train_direction > 0: destination.x -= 0.5 * Globals.module_width
	constrain_destination()
	if distanceToTarget > 7:
		if targetNeed != "": new_thought("It's a long way to fulfil my %s" %  [targetNeed])
		elif targetWork != "": new_thought("It's a long way to find %s work" %  [targetWork])

# adjust the need, and return the amount remaining
func adjust_need(type : String, amount : float) -> float:
	needs[type] = max(needs[type] - amount, 0)
	return needs[type]

func new_thought(text : String):
	if thoughts.size() > 0 and thoughts.get(thoughts.size() - 1) == text:
		return
	thoughts.append(text)
	var prefix = ("%s %s: " % [firstname, lastname])
	text = prefix + text
	Globals.activeUI.add_thought(text)

func show_passenger_panel():
	displayNeeds = !displayNeeds
	if displayNeeds:
		passengerPanel = displayNeedsScene.instantiate()
		add_child(passengerPanel)
		passengerPanel.update_step()
	else:
		passengerPanel.queue_free()
		passengerPanel = null

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.is_action_pressed("left_click"):
		show_passenger_panel()
