extends Control

class_name TrainUI

var selectedTrain : Train = null
@onready var textbox : LineEdit = find_child("LineEdit")
var tick_time : float = 0.0
var tick_timer : Timer = Timer.new()

@onready var worldMap : MapHandler = get_node("WorldMap")

@onready var thoughtsPanel : Panel = get_node("ThoughtsPanel")
@onready var constructionPanel : ConstructionPanel = get_node("constructionPanel")
@onready var thoughtsList : ItemList = thoughtsPanel.get_node("ThoughtsList")

@onready var debug_slider : HSlider = get_node("DebugPanel/DebugSlider")

@onready var resource_panel : ResourcePanel = $ResourcePanel
@onready var sunInfo = get_node("sunInfo")
var jobsControllerScene : PackedScene = preload("res://Scenes/JobsController.tscn")
var jobsController : Panel = null
var expeditionsControllerScene : PackedScene = preload("res://Scenes/expeditions_panel.tscn")
var expeditionsController : ExpeditionsController = null
var backgroundController : BackgroundManager = null
var pending_module_type : String = ""

func do_resource_tick():
	selectedTrain.resource_tick()
	resource_panel_update()
	worldMap.train_step()
	Globals.game_tick += 1
	sunInfo.text="Temp: %d Solar: %f" % [selectedTrain.train_temperature, selectedTrain.sunIntensity]
	
	if expeditionsController != null:
		expeditionsController.train_tick()
	
	backgroundController.update_sun_state()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	Globals.activeUI = self

	worldMap.select_new_train(get_parent().get_node("Train"))
	selectedTrain = get_parent().get_node("Train")

	var update_timer : Timer = Timer.new()
	add_child(update_timer)
	update_timer.wait_time = 0.5
	update_timer.one_shot = false
	update_timer.timeout.connect(resource_panel_update)
	update_timer.start()

	add_child(tick_timer)
	tick_timer.timeout.connect(do_resource_tick)
	tick_timer.wait_time = Globals.tick_duration
	tick_timer.one_shot = false
	tick_timer.start()

	resource_panel.setup(selectedTrain)

	backgroundController = get_parent().get_node("Background")
	constructionPanel.placement_requested.connect(_on_construction_placement_requested)

func _on_viewport_size_changed() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resource_panel.apply_panel_width()
	constructionPanel.apply_panel_layout()
	


func _unhandled_input(event: InputEvent) -> void:
	if pending_module_type == "":
		return
	if event is InputEventMouseButton and event.is_action_pressed("left_click"):
		if _is_click_over_ui(event.global_position):
			return
		_place_module_at_click(event.global_position)
		get_viewport().set_input_as_handled()

func _on_construction_placement_requested(module_type: String) -> void:
	pending_module_type = module_type
	add_thought("Select a slot on the train to place %s." % module_type)

func _place_module_at_click(global_position: Vector2) -> void:
	# Match passenger/module coords: get_trainpos_from_coords expects PassengersManager-local space.
	var placement_local_pos: Vector2 = selectedTrain.passengerManager.to_local(global_position)
	var train_pos: Array[int] = Helpers.get_trainpos_from_coords(placement_local_pos)
	selectedTrain.add_module(pending_module_type, train_pos[0], train_pos[1])
	_clear_placement_mode()

func _is_click_over_ui(global_position: Vector2) -> bool:
	return constructionPanel.get_global_rect().has_point(global_position)

func _clear_placement_mode() -> void:
	pending_module_type = ""

func resource_panel_update() -> void:
	resource_panel.update_from_train(selectedTrain)

func add_thought(newThought : String):
	var listPos : int = thoughtsList.add_item(newThought, null, false)
	thoughtsList.move_item(listPos, 0)

func _on_line_edit_text_submitted(_new_text: String) -> void:
	parse_text_input()
	pass # Replace with function body.

func _on_textinput_press():
	parse_text_input()
	pass

func parse_text_input():
	var verb = ""
	var subject = ""
	var allSubjects : bool = false
	var location1 = ""
	var location2 = ""

	var text = textbox.text
	text = text.to_lower()
	text.rstrip("\n")
	print_debug(text)
	var words : PackedStringArray = text.split(" ")
	textbox.text = ""	# Clear textbox
	var i = 0
	
	while i < words.size():
		var wordsRead = 1
		
		if i == 0 and words[i] == "tick":
			verb = "resource_tick" 
			do_resource_tick()
			return
		
		if words[i] == "build" or words[i] == "add":
			verb = "build"
		elif words[i] == "remove" or words[i] == "destroy":
			verb = "deconstruct"
		elif words[i] == "disable" or words[i] == "deactivate":
			verb = "deactivate"
		elif words[i] == "turn" and words[i+1] == "off":
			verb = "deactivate"
			wordsRead = 2
		elif words[i] == "enable" or words[i] == "activate":
			verb = "activate"
		elif words[i] == "turn" and words[i+1] == "on": 
			verb = "activate"
			wordsRead = 2
		elif words[i] == "all" or words[i] == "every":
			allSubjects = true
		elif words[i] == "empty":
			subject = "empty"
		elif words[i] == "cabin":
			subject = "cabin"
		elif words[i] == "door":
			subject = "passenger_door"
		elif words[i] == "greywater" or words[i] == "graywater" or words[i] == "grey_water":
			subject = "grey_water"
		elif words[i] == "grey" and words[i+1] == "water":
			subject = "grey_water"
			wordsRead = 2
		elif words[i] == "cleanwater" or words[i] == "clean_water":
			subject = "clean_water"
		elif words[i] == "clean" and words[i+1] == "water":
			subject = "clean_water"
			wordsRead = 2
		elif words[i] == "blackwater" or words[i] == "black_water":
			subject = "black_water"
		elif words[i] == "black" and words[i+1] == "water":
			subject = "black_water"
			wordsRead = 2
		elif words[i] == "scrap":
			subject = "scrap_arm"
		elif words[i] == "farm":
			subject = "farm"
		elif words[i] == "food" or  words[i] == "kitchen":
			subject = "kitchen"
		elif words[i] == "water":
			subject = "clean_water"
		elif words[i] == "mechparts" or words[i] == "mech_parts" or words[i] == "mechanicalparts" or words[i] == "mechanical_parts":
			subject = "mech_parts"
		elif (words[i] == "mech" or words[i] == "mechanical") and words[i+1] == "parts":
			subject = "mech_parts"
			wordsRead = 2
		elif words[i] == "water"  and words[i+1] == "collector":
			subject = "water_collector"
			wordsRead = 2
		elif words[i] == "water_collector":
			subject = "water_collector"
		elif words[i] == "fuel_refinery":
			subject = "fuel_refinery"
		elif (words[i] == "car" or words[i] == "carriage") and words[i+1].is_valid_int():
			location1 = words[i+1]
			wordsRead = 2
		elif (words[i] == "slot" or words[i] == "position" or words[i] == "pos") and words[i+1].is_valid_int():
			location2 = words[i+1]
			wordsRead = 2
		elif (words[i].is_valid_int() and location1 == ""):
			location1 = words[i]
		elif (words[i].is_valid_int() and location2 == ""):
			location2 = words[i]
		
		i += wordsRead
	print_debug("Input: " + verb + " " + subject + " " + location1 + " " + location2)
	if verb != "" and subject != "" and location1 != "" and location2 != "":
		if verb == "build":
			selectedTrain.add_module(subject, location1.to_int(), location2.to_int())
			return
		elif verb == "deconstruct":
			selectedTrain.remove_module(location1.to_int(), location2.to_int())


func _on_debug_tick_pressed() -> void:
	do_resource_tick()
	pass # Replace with function body.

func _on_add_passenger_pressed() -> void:
	selectedTrain.add_passenger_debug()
	pass # Replace with function body.


func _on_debug_tick_slider_ended(value_changed: bool) -> void:
	if value_changed == true:
		$DebugPanel/SliderLabel.text = ("%f" % (debug_slider.value))
		tick_time = 1.0 / debug_slider.value
		tick_timer.wait_time = tick_time
		Globals.time_factor = debug_slider.value
		if tick_time == 0.0:
			tick_timer.stop()
		else:
			tick_timer.start()


func _on_map_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		worldMap.show()
	else:
		worldMap.hide()
	pass # Replace with function body.

func _on_thoughts_toggle_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		thoughtsPanel.show()
	else:
		thoughtsPanel.hide()
	pass # Replace with function body.


func _on_car_button_pressed() -> void:
	selectedTrain.add_car()

func _on_JobController_open_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		if jobsController == null:
			jobsController = jobsControllerScene.instantiate()
			add_child(jobsController)
			jobsController.init_control()
		else:
			jobsController.show()
	else:
		jobsController.hide()


func _on_ExpeditionsController_open_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		if expeditionsController == null:
			expeditionsController = expeditionsControllerScene.instantiate()
			add_child(expeditionsController)
		else:
			expeditionsController.show()
			expeditionsController.refresh_options()
	else:
		expeditionsController.hide()


func _on_construct_toggled(toggled_on: bool) -> void:
	if toggled_on == true :
		constructionPanel.show()
		constructionPanel.setup()
	else:
		_clear_placement_mode()
		constructionPanel.hide()
		constructionPanel.teardown()
