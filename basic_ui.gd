extends Control

class_name TrainUI

var selectedTrain : Train = null
@onready var textbox : LineEdit = find_child("LineEdit")
var tick_time : float = 0.0
var tick_timer : Timer = Timer.new()

@onready var worldMap : MapHandler = get_node("WorldMap")

@onready var thoughtsPanel : Panel = get_node("ThoughtsPanel")
@onready var constructionPanel : ConstructionPanel = get_node("constructionPanel")
@onready var stopSchedulePanel : StopSchedulePanel = get_node("StopSchedulePanel")
@onready var thoughtsList : ItemList = thoughtsPanel.get_node("ThoughtsList")

@onready var debug_slider : HSlider = get_node("DebugPanel/DebugSlider")
@onready var map_toggle : CheckButton = get_node("DebugPanel/CheckButton")

@onready var resource_panel : ResourcePanel = $ResourcePanel
@onready var sunInfo = get_node("sunInfo")
var jobsControllerScene : PackedScene = preload("res://Scenes/JobsController.tscn")
var jobsController : Panel = null
var expeditionsControllerScene : PackedScene = preload("res://Scenes/expeditions_panel.tscn")
var expeditionsController : ExpeditionsController = null
var backgroundController : BackgroundManager = null
var pending_module_type : String = ""
var scene_root : Node = null
var _world_map_rest_position : Vector2 = Vector2.ZERO
var _world_map_rest_scale : Vector2 = Vector2.ONE
var _world_map_rest_z_index : int = 0
var _world_map_is_fullscreen : bool = false

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
	scene_root = get_tree().current_scene

	worldMap.select_new_train(scene_root.get_node("Train"))
	selectedTrain = scene_root.get_node("Train")

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

	backgroundController = scene_root.get_node("Background")
	constructionPanel.placement_requested.connect(_on_construction_placement_requested)
	EventBus.time_factor_requested.connect(_on_time_factor_requested)

	_world_map_rest_position = worldMap.position
	_world_map_rest_scale = worldMap.scale
	_world_map_rest_z_index = worldMap.z_index
	worldMap.show()
	if map_toggle.button_pressed:
		_world_map_is_fullscreen = true
		_apply_world_map_fullscreen()
		worldMap.set_map_node_clicks_enabled(true)
	else:
		_world_map_is_fullscreen = false
		_restore_world_map_layout()
		worldMap.set_map_node_clicks_enabled(false)


func _exit_tree() -> void:
	if EventBus.time_factor_requested.is_connected(_on_time_factor_requested):
		EventBus.time_factor_requested.disconnect(_on_time_factor_requested)

func _on_viewport_size_changed() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resource_panel.apply_panel_width()
	constructionPanel.apply_panel_layout()
	if _world_map_is_fullscreen:
		_apply_world_map_fullscreen()


func _unhandled_input(event: InputEvent) -> void:
	if pending_module_type == "":
		return
	if event is InputEventMouseButton and event.is_action_pressed("left_click"):
		if _is_click_over_ui(event.global_position):
			return
		_place_module_at_click(event.position)
		get_viewport().set_input_as_handled()

func _on_construction_placement_requested(module_type: String) -> void:
	pending_module_type = module_type
	selectedTrain.refresh_module_click_areas()
	add_thought("Select a slot on the train to place %s." % module_type)

func place_module_at_slot(car_num: int, slot: int) -> void:
	if pending_module_type == "":
		return
	selectedTrain.add_module(pending_module_type, car_num, slot)
	_clear_placement_mode()

func _place_module_at_click(viewport_position: Vector2) -> void:
	var world_pos: Vector2 = TrainCamera.viewport_to_world(get_viewport(), viewport_position)
	var placement_local_pos: Vector2 = selectedTrain.passengerManager.to_local(world_pos)
	var train_pos: Array[int] = Helpers.get_trainpos_from_coords(placement_local_pos)
	place_module_at_slot(train_pos[0], train_pos[1])

func _is_click_over_ui(global_position: Vector2) -> bool:
	return constructionPanel.get_global_rect().has_point(global_position)

func _clear_placement_mode() -> void:
	pending_module_type = ""
	if selectedTrain != null:
		selectedTrain.refresh_module_click_areas()

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
		elif words[i] == "expedition" and i + 1 < words.size() and words[i + 1] == "room":
			subject = "expedition_room"
			wordsRead = 2
		elif words[i] == "door" or words[i] == "expedition":
			subject = "expedition_room"
		elif words[i] == "greywater" or words[i] == "graywater" or words[i] == "grey_water":
			subject = "grey_water"
		elif words[i] == "grey" and words[i+1] == "water":
			subject = "grey_water"
			wordsRead = 2
		elif words[i] == "cleanwater" or words[i] == "clean_water":
			subject = "water_purifier"
		elif words[i] == "clean" and words[i+1] == "water":
			subject = "water_purifier"
			wordsRead = 2
		elif words[i] == "purifier" or words[i] == "water_purifier":
			subject = "water_purifier"
		elif (words[i] == "water" or words[i] == "sewage") and words[i+1] == "purifier":
			subject = "water_purifier"
			wordsRead = 2
		elif words[i] == "sewage_works" or words[i] == "sewageworks":
			subject = "sewage_works"
		elif words[i] == "sewage" and words[i+1] == "works":
			subject = "sewage_works"
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
			subject = "water_purifier"
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
		EventBus.request_time_factor(debug_slider.value)


func _on_time_factor_requested(new_time_factor: float) -> void:
	_apply_time_factor(new_time_factor)


func _apply_time_factor(new_time_factor: float) -> void:
	Globals.time_factor = new_time_factor
	if new_time_factor <= 0.0:
		tick_time = 0.0
		tick_timer.stop()
	else:
		tick_time = 1.0 / new_time_factor
		tick_timer.wait_time = tick_time
		tick_timer.start()
	debug_slider.set_value_no_signal(new_time_factor)
	$DebugPanel/SliderLabel.text = "%f" % new_time_factor


func _on_map_toggled(toggled_on: bool) -> void:
	worldMap.show()
	if toggled_on:
		_world_map_is_fullscreen = true
		_apply_world_map_fullscreen()
		worldMap.set_map_node_clicks_enabled(true)
	else:
		_world_map_is_fullscreen = false
		_restore_world_map_layout()
		worldMap.set_map_node_clicks_enabled(false)


func _apply_world_map_fullscreen() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var fit_scale: float = minf(
		viewport_size.x / MapHandler.MAP_CONTENT_SIZE.x,
		viewport_size.y / MapHandler.MAP_CONTENT_SIZE.y
	)
	var scaled_size: Vector2 = MapHandler.MAP_CONTENT_SIZE * fit_scale
	worldMap.scale = Vector2(fit_scale, fit_scale)
	worldMap.position = (viewport_size - scaled_size) * 0.5
	worldMap.z_index = 100


func _restore_world_map_layout() -> void:
	worldMap.position = _world_map_rest_position
	worldMap.scale = _world_map_rest_scale
	worldMap.z_index = _world_map_rest_z_index

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


#func _on_schedule_toggled(toggled_on: bool) -> void:
func _on_stop_scheduler_button_toggled(toggled_on: bool) -> void:
	if toggled_on == true :
		stopSchedulePanel.show()
		stopSchedulePanel.setup()
	else:
		stopSchedulePanel.hide()
