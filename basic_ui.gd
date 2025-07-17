extends Control

class_name TrainUI

@onready var selectedTrain : Train = get_parent().find_child("Train")
@onready var textbox : LineEdit = find_child("LineEdit")
var tick_time : float = 0.0
var tick_timer : Timer = Timer.new()

@onready var worldMap : MapHandler = find_child("WorldMap")

@onready var thoughtsPanel : Panel = find_child("ThoughtsPanel")
@onready var thoughtsList : ItemList = thoughtsPanel.find_child("ThoughtsList")

@onready var debug_slider : HSlider = find_child("DebugPanel").find_child("DebugSlider")

@onready var resource_detail : Panel = null

func do_resource_tick():
	selectedTrain.resource_tick()
	resource_panel_update()
	worldMap.train_step()
	Globals.game_tick += 1

func _ready() -> void:
	Globals.activeUI = self
	
	worldMap.select_new_train(get_parent().find_child("Train"))
	
	var update_timer : Timer = Timer.new()
	add_child(update_timer)
	update_timer.wait_time = 0.5
	update_timer.one_shot = false
	update_timer.timeout.connect(resource_panel_update)
	update_timer.start()
	
	# Setup tick_timer
	add_child(tick_timer)
	tick_timer.timeout.connect(do_resource_tick)
	tick_timer.wait_time = 2.0
	tick_timer.one_shot = false
	tick_timer.start()
	
	# Set initial state for Resource Detail hover-panel
	resource_detail = get_node("ResourcePanel/ResourceDetailPanel")
	resource_detail.hide()
	setup_hover_signals()
	
func setup_hover_signals():
	var speedNode : RichTextLabel = get_node("ResourcePanel/Speed")
	var fuelNode : RichTextLabel = get_node("ResourcePanel/Fuel")
	var popNode : RichTextLabel = get_node("ResourcePanel/Pop")
	var waterNode : RichTextLabel = get_node("ResourcePanel/CleanWater")
	var greyNode : RichTextLabel = get_node("ResourcePanel/GreyWater")
	var blackNode : RichTextLabel = get_node("ResourcePanel/BlackWater")
	var foodNode : RichTextLabel = get_node("ResourcePanel/Food")
	var partsNode : RichTextLabel = get_node("ResourcePanel/MechParts")
	var scrapNode : RichTextLabel = get_node("ResourcePanel/Scrap")

	fuelNode.mouse_entered.connect(_on_mouse_res_hover.bind("fuel",fuelNode.position.x))
	waterNode.mouse_entered.connect(_on_mouse_res_hover.bind("clean_water",waterNode.position.x))
	greyNode.mouse_entered.connect(_on_mouse_res_hover.bind("grey_water",greyNode.position.x))
	blackNode.mouse_entered.connect(_on_mouse_res_hover.bind("black_water",blackNode.position.x))
	foodNode.mouse_entered.connect(_on_mouse_res_hover.bind("food1",foodNode.position.x))
	partsNode.mouse_entered.connect(_on_mouse_res_hover.bind("mech_parts",partsNode.position.x))
	scrapNode.mouse_entered.connect(_on_mouse_res_hover.bind("scrap",scrapNode.position.x))
	
	fuelNode.mouse_exited.connect(_on_mouse_res_leave.bind())
	waterNode.mouse_exited.connect(_on_mouse_res_leave.bind())
	greyNode.mouse_exited.connect(_on_mouse_res_leave.bind())
	blackNode.mouse_exited.connect(_on_mouse_res_leave.bind())
	foodNode.mouse_exited.connect(_on_mouse_res_leave.bind())
	partsNode.mouse_exited.connect(_on_mouse_res_leave.bind())
	scrapNode.mouse_exited.connect(_on_mouse_res_leave.bind())
	pass


func resource_panel_update():
	$ResourcePanel/Speed.text = "Speed: " + Helpers.pretty_print_float(selectedTrain.speed)
	$ResourcePanel/Fuel.text = "Fuel: " + Helpers.pretty_print_float(selectedTrain.get_res("fuel"))
	$ResourcePanel/Pop.text = "Pop: " + String.num_int64(selectedTrain.passengerManager.passengers.size())
	$ResourcePanel/CleanWater.text = "Water: " + Helpers.pretty_print_float(selectedTrain.get_res("clean_water"))
	$ResourcePanel/GreyWater.text = "Grey: " + Helpers.pretty_print_float(selectedTrain.get_res("grey_water"))
	$ResourcePanel/BlackWater.text = "Black: " + Helpers.pretty_print_float(selectedTrain.get_res("black_water"))
	$ResourcePanel/MechParts.text = "Parts: " + Helpers.pretty_print_float(selectedTrain.get_res("mech_parts"))
	$ResourcePanel/Food.text = "Food: " + Helpers.pretty_print_float(selectedTrain.get_res("food1"))
	$ResourcePanel/Scrap.text = "Scrap: " + Helpers.pretty_print_float(selectedTrain.get_res("scrap"))

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

func _on_mouse_res_hover(resource_type : String, xPos : float) -> void:
	resource_detail.position.x = xPos
	resource_detail.get_node("TypeLabel").text = resource_type
	
	if selectedTrain.res.has(resource_type) and selectedTrain.max_res.has(resource_type):
		var valueLabel = resource_detail.get_node("ValueLabel")
		valueLabel.text = "%s / %s" % [Helpers.pretty_print_float(selectedTrain.res[resource_type]), Helpers.pretty_print_float(selectedTrain.max_res[resource_type])]
		resource_detail.show()
	pass

func _on_mouse_res_leave() -> void:
	resource_detail.hide()
