extends Panel

class_name ActiveExpedition

var index : int = 0    # Used if there are multiples of the same expedition type active
var original_name : String = ""
var pop : int = 0
var passengers : Array[Passenger] = []
var total_duration : int = 0
var travel_time : int = 0
var time_passed : int = 0
var collection_time : int = 0
var resource_spot : MapResourceContainer = null
var is_scavenge : bool = false
var scavenge_location : MapLocation = null

var target_resources : Array = []
var resources_gathered : Dictionary = {}
const my_scene = preload("res://Scenes/active_expedition.tscn")

# Sizing constants
const fetch_panel_base_width : float = 10.0
const fetch_panel_width_per_item : float = 50.0
var progress_background_width : float = 200.0

# Node references
var name_label : Label = null
var pop_label : Label = null
var fetch_panel : Panel = null
var sprite1 : Sprite2D = null
var sprite2 : Sprite2D = null
var label1 : Label = null
var label2 : Label = null
var time_label : Label = null
var progress_bar : Panel = null
var return_button : Button = null

static func new_expedition(_index : int, optionSelected : ExpeditionOption, passengersArray : Array[Passenger]):
	var _new_expedition : ActiveExpedition = my_scene.instantiate()
	_new_expedition.index = _index
	_new_expedition.original_name = optionSelected.display_name
	_new_expedition.pop = optionSelected.pop_allocated
	_new_expedition.total_duration = optionSelected.time_needed
	_new_expedition.travel_time = optionSelected.travel_time
	_new_expedition.target_resources = optionSelected.gains_per_pop
	_new_expedition.passengers = passengersArray
	_new_expedition.resource_spot = optionSelected.resource_spot
	_new_expedition.is_scavenge = optionSelected.is_scavenge
	_new_expedition.scavenge_location = optionSelected.scavenge_location
	return _new_expedition

func _ready():
	name_label = get_node("NameLabel")
	pop_label = get_node("FetchPanel/PopLabel")
	fetch_panel = get_node("FetchPanel")
	sprite1 = get_node("FetchPanel/Sprite1")
	sprite2 = get_node("FetchPanel/Sprite2")
	label1 = get_node("FetchPanel/Label1")
	label2 = get_node("FetchPanel/Label2")
	time_label = get_node("ProgressBackground/TimeLabel")
	progress_bar = get_node("ProgressBackground/ProgressBar")
	progress_background_width = get_node("ProgressBackground").size.x
	return_button = get_node("ReturnButton")
	return_button.pressed.connect(_on_return_button_pressed)
	collection_time = total_duration - (2 * travel_time)
	
	self.name_label.text = "%s %d" % [original_name, index]
	self.pop_label.text = "%d" % pop
	self.fetch_panel.size.x = (fetch_panel_base_width * 2) + (fetch_panel_width_per_item * (target_resources.size() + 1))
	self.time_label.text = "%s" % Helpers.seconds_to_mm_ss(total_duration - time_passed)
	
	for i in range(target_resources.size()):
		var target = target_resources[i]
		var type_name: String = target[0]
		if i == 0:
			_apply_resource_icon(sprite1, type_name)
			label1.text = "?" if is_scavenge else ""
			sprite1.show()
			label1.show()
		elif i == 1:
			_apply_resource_icon(sprite2, type_name)
			label2.text = ""
			sprite2.show()
			label2.show()

func train_tick():
	time_passed += 1
	if not is_scavenge and time_passed >= travel_time and time_passed < (total_duration - travel_time):
		collect_resources()
	self.time_label.text = "%s" % Helpers.seconds_to_mm_ss(total_duration - time_passed)
	progress_bar.size.x = (progress_background_width / total_duration * time_passed)

func collect_resources():
	for i in range(target_resources.size()):
		var resourceType = target_resources[i][0]
		var max_per_person = target_resources[i][1]
		var amount_to_add : float = max_per_person * float(pop) / collection_time
		amount_to_add = min(amount_to_add, resource_spot.amount)
		if resources_gathered.has(resourceType):
			resources_gathered[resourceType] = resources_gathered[resourceType] + amount_to_add
		else:
			resources_gathered[resourceType] = amount_to_add
		
		## Update display labels with new values
		if i == 0:
			label1.text = ResourceTypeRegistry.format_amount(resourceType, resources_gathered[resourceType])
		elif i == 1:
			label2.text = ResourceTypeRegistry.format_amount(resourceType, resources_gathered[resourceType])
		
		## Remove the resources from the MapResourceContainer, end expedition if resource is empty
		resource_spot.amount -= amount_to_add
		if (resource_spot.amount  <= 0):
			print("Location has run out of this resource!")
			_on_return_button_pressed()

func _on_return_button_pressed():
	if time_passed < travel_time + collection_time:
		time_passed = travel_time + collection_time
	return_button.text = "Abandon"
	return_button.pressed.disconnect(_on_return_button_pressed)
	return_button.pressed.connect(_on_abandon_button_pressed)

func _on_abandon_button_pressed():
	get_parent().get_parent().abandon_expedition(self)


func _apply_resource_icon(sprite: Sprite2D, type_name: String) -> void:
	var resource_type := ResourceTypeRegistry.get_type(type_name)
	sprite.texture = resource_type.iconTexture
	sprite.modulate = resource_type.iconModulate
