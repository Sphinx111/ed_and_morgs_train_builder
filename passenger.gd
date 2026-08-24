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
var goal_travel_pull : float = 0.0
var wander_time_remaining : float = 0.0

var home_cabin = null
var is_in_module : bool = false
var is_working : bool = false
var is_on_expedition : bool = false

# Foodtypes and last tick they were eaten on (to track food variety)
var foodsEaten = {
	"food1" : 0
}
var water_content : float = 0.0

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
const WANDER_DURATION : float = 2.0

var temp_tolerance : float = 40.0 # At this temp, passenger consumes most resources
var temp_stress_tolerance : float = temp_tolerance - Globals.train_base_temp # Amount above base temp
var temp_death : float = 60.0 # At this temp, the passenger dies
var water_consumption_at_tolerance : float = 4.0

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
	water_content = randf_range(0.0, 0.5)

func _process(delta: float) -> void:
	if is_in_module or is_on_expedition:
		return
	if direction == 0:
		return

	var step : float = direction * movespeed * delta * Globals.time_factor
	position.x = clampf(position.x + step, parentTrain.minXpos, parentTrain.maxXpos)

	if (direction > 0 and position.x > next_module_pos) or (direction < 0 and position.x < last_module_pos):
		update_module_positions()

	if wander_time_remaining > 0.0:
		wander_time_remaining = maxf(0.0, wander_time_remaining - delta * Globals.time_factor)
		if wander_time_remaining == 0.0:
			direction = 0

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

func enter_customer_module(target : ModuleBase, _attemptNo : int) -> void:
	if target.can_enter(self):
		if self.is_in_module == false:
			target.add_customer(self)
			current_module = target
			#self.position.y -= 20 + (randf() * 30)
			self.hide()
			is_in_module = true

			if passengerPanel != null:
				passengerPanel.actionLabel.text = "being served"

func enter_worker_module(target : ModuleBase, _attemptNo : int) -> void:
	if self.is_in_module == false:
		if target.worker_can_enter(self):
			target.add_worker(self)
			current_module = target
			self.hide()
			if passengerPanel != null:
				passengerPanel.actionLabel.text = "working"
			is_in_module = true
			is_working = true

## Used by passenger to tell module they're leaving
func exit_customer_module():
	ejected_from_module()
	current_module.notify_remove_customer(self)

## Used by modules to eject a passenger
func ejected_from_module():
	self.show()
	targetNeed = ""
	is_in_module = false
	is_working = false

## Used by passenger to tell module they're leaving
func exit_worker_module():
	self.show()
	targetWork = ""
	is_in_module = false
	is_working = false
	current_module.notify_remove_worker(self)

## Used by modules to eject a worker
func worker_ejected_from_module():
	self.show()
	targetWork = ""
	is_in_module = false
	is_working = false

func resource_tick(_train_temperature : float):
	for key in needs.keys():
		if key == "thirst":
			var temp_stress : float = _train_temperature - Globals.train_base_temp
			needs[key] += (Globals.need_growth_rates[key] * temp_stress / temp_stress_tolerance * water_consumption_at_tolerance);
		else:
			needs[key] += Globals.need_growth_rates[key]
	if _train_temperature >= temp_death:
		is_dying = true;
	check_needs()
	
	check_for_work()
	if Globals.passenger_debug == true:
		update_needs_debug()
	pick_direction()
	if passengerPanel != null:
		passengerPanel.update_step()

func wants_need(type : String) -> float:
	if needs.has(type):
		return (needs[type])
	return 0.0

## Called to remove itself from any modules, this passenger is about to die
func cleanup():
	position.y = 0
	if is_working and is_in_module:
		current_module.notify_remove_worker(self)
		is_working = false
		is_in_module = false
	elif is_in_module:
		current_module.notify_remove_customer(self)
		is_in_module = false

func check_needs():
	if is_on_expedition == true:
		return
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

## Used before passengers are sent on an expedition
func fix_all_needs():
	for key in needs.keys():
		needs[key] = 0.0

func check_for_work():
	targetWork = manager.get_next_work_priority()
	check_current_module()

## Allows different results from hitting max need. Not all needs will be fatal
func hit_max_need(needType : String) -> int:
	print("%s %s: Oh no! I am dying of %s" % [firstname, lastname, needType])
	return Globals.RESULT_FATAL

func pick_direction() -> void:
	if targetNeed != "" or targetWork != "":
		_pick_goal_direction()
		return

	goal_travel_pull = 0.0
	_start_wander_if_due()


func _pick_goal_direction() -> void:
	var my_location : Array[int] = Helpers.get_trainpos_from_coords(self.position)
	goal_travel_pull = _get_goal_travel_pull(my_location)

	if goal_travel_pull == PassengerVectorMap.NO_DIRECTION:
		if targetNeed != "":
			new_thought("I can't find anywhere to fulfil my crushing %s need!" % targetNeed)
		_start_wander_if_due()
		return

	wander_time_remaining = 0.0

	if goal_travel_pull == 0.0:
		direction = 0
		check_current_module()
		return

	direction = _travel_pull_to_direction(goal_travel_pull)

	if absf(goal_travel_pull) > 7.0:
		if targetNeed != "":
			new_thought("It's a long way to fulfil my %s" % targetNeed)
		elif targetWork != "":
			new_thought("It's a long way to find %s work" % targetWork)


func _start_wander_if_due() -> void:
	if wander_time_remaining > 0.0:
		return
	_start_wander()


func _start_wander() -> void:
	if randf() >= Globals.idle_wander_chance:
		direction = 0
		return
	direction = 1 if randf() < 0.5 else -1
	if Globals.train_direction > 0:
		direction *= -1
	wander_time_remaining = WANDER_DURATION


func _get_goal_travel_pull(my_location : Array[int]) -> float:
	if targetNeed != "":
		return parentTrain.passengerMap.get_travel_pull_at(my_location, targetNeed, "need")
	if targetWork != "":
		return parentTrain.passengerMap.get_travel_pull_at(my_location, targetWork, "work")
	return PassengerVectorMap.NO_DIRECTION


func _travel_pull_to_direction(travel_pull : float) -> int:
	var travel_direction : int = 1 if travel_pull > 0.0 else -1
	if Globals.train_direction > 0:
		travel_direction *= -1
	return travel_direction

# adjust the need, and return the amount remaining
func adjust_need(type : String, amount : float) -> float:
	needs[type] = max(needs[type] - amount, 0)
	return needs[type]

# adjust the water_content, and return the new value
func adjust_water_content(amount : float) -> float:
	water_content += amount
	return water_content
	

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

func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.is_action_pressed("left_click"):
		show_passenger_panel()
