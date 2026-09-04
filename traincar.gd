extends Node2D

class_name TraincarBase

# The car's position in the train
var sequence : int = 0
var parentTrain : Train = null

# Base mass of the TrainCar
var mass : float = 1000.0

# List of modules in the car
var modules : Array[ModuleBase] = [null, null, null, null]
var ModuleScene = preload("res://Scenes/module.tscn")
var defaultModuleArray = ["water_purifier", "cabin", "cabin", "cabin"]

# Environmental Variables
var moisture_requested : int = 1.0
var moisture_level : int = 0
var water_consumption_per_level : float = 0.1

func _ready():
	if Globals.train_direction < 0:
		position.x = sequence * (Globals.car_length + Globals.car_separation)
	else:
		# Pos      = Train origin           - Leftwards for each car in sequence                         - extra because drawing is from the left
		position.x = 0 - ((sequence + 1) * (Globals.car_length + Globals.car_separation)) - Globals.car_length
	$Outline.size.x = Globals.car_length
	$Outline.size.y = Globals.car_height
	parentTrain = get_parent()
	
	for i in range(4):
		init_module("empty", i)

func set_sequence(newSequence : int):
	sequence = newSequence
	if Globals.train_direction < 0:
		position.x = sequence * (Globals.car_length + Globals.car_separation)
	else: 
		position.x = 0 - ((sequence + 1) * (Globals.car_length + Globals.car_separation)) - Globals.car_length
		
	if newSequence == 0:
		for i in range(4):
			modules[i].set_type(defaultModuleArray[i])


func resource_tick():
	var water_required : float = moisture_requested * water_consumption_per_level
	if parentTrain.gather_res("clean_water", water_required) == Globals.RESULT_OK:
		moisture_level = moisture_requested
		parentTrain.add_res("grey_water", water_required)
	else:
		moisture_level = 0
		$MoistureSlider.value = 0
		
	for module in modules:
		if module != null:
			module.resource_tick()

func init_module(type : String, position : int) -> void:
	var new_module : ModuleBase = ModuleScene.instantiate()
	add_child(new_module)
	new_module.set_type(type)
	new_module.set_sequence(position)

	if modules[position] != null:
		new_module.customers = modules[position].customers
		new_module.workers = modules[position].workers
		modules[position].queue_free()

	modules[position] = new_module

func add_module(type : String, slot : int):
	modules[slot].set_type(type)
	recalculateAdjacencies()
	
# TODO: last slot seems to not get adjacencie bonuses test more then fix
func recalculateAdjacencies():
	for i in range(0,4):
		var newVal : int = 0
		var type=modules[i].type
		if i>0 and modules[i-1].type == type :
			newVal += 1
		if i<3 and modules[i+1].type== type :
			newVal += 1
		modules[i].set_adjacency(newVal)

func remove_module(slot: int):
	modules[slot].set_type("empty")
	recalculateAdjacencies()

func get_type_map(need_type_to_find : String) -> Array:
	var result = [0,0,0,0]
	for i in range(4):
		if modules[i].can_serve_need(need_type_to_find):
			result[i] = 1
	return result

func get_work_map(work_type_to_find : String) -> Array:
	var result = [0,0,0,0]
	for i in range(4):
		if modules[i].needs_worker(work_type_to_find):
			result[i] = 1
	return result

func update_needs_maps(needsArray : Array[String], modulePos : int, newState : int):
	parentTrain.update_needs_maps(needsArray, [sequence, modulePos], newState)

func update_work_maps(workArray : Array[String], modulePos : int, newState : int):
	parentTrain.update_work_maps(workArray, [sequence, modulePos], newState)

func _on_moisture_slider_value_changed(value: float) -> void:
	moisture_requested = int(value)
