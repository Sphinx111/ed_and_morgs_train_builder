extends Panel

class_name ExpeditionOption
## This class holds variables for an expedition, and controls how it displays in the Expeditions Tracker
@export var display_name : String = "Collect Scrap"

const my_scene = preload("res://Scenes/expedition_option.tscn")

var controller : ExpeditionsController = null

var min_pop : int = 4        ## Minimum number of people required for expedition
var time_needed : int = 190  ## Time required for expedition, in game ticks
var travel_time : int = 60
var resource_spot : ResourceSpot = null

# List of resources which can be gained from the expedition
#  [resource name, amount, chance to find, texture to use, and icon color modulate]
var max_gain : Array = [["scrap", 25, 1.0, Globals.scrap_texture, Color.WHITE]]

const default_gains : Dictionary = {
	"scrap" : ["scrap", 25, 1.0, Globals.scrap_texture, Color.WHITE],
	"clean_water" : ["clean_water", 15, 1.0, Globals.water_texture, Color.AQUA],
	"pop" : ["pop", 2, 1.0, Globals.pop_texture, Color.WHITE]
}

# List of resources required to launch the expedition, per person
#  [resource name, amount, texture to use, icon color modulate
var costs : Array = [["pop", 1, Globals.pop_texture, Color.WHITE],
					 ["clean_water", 2, Globals.water_texture, Color.AQUA],
					 ["food1", 1, Globals.food_texture, Color.SADDLE_BROWN]]

const default_costs : Dictionary = {
	"pop" : ["pop", 1, Globals.pop_texture, Color.WHITE],
	"clean_water" : ["clean_water", 2, Globals.water_texture, Color.AQUA],
	"food1" : ["food1", 1, Globals.food_texture, Color.SADDLE_BROWN]
}

# Tracking variables
var pop_allocated : int = 4

# sizing constants
const width_per_cost : float = 50.0
const limit_cost_items : int = 3
const limit_gain_items : int = 1

# Node references
var name_label : Label = null
var gain_panel : Panel = null
var gain_sprite : Sprite2D = null
var gain_label : Label = null

var cost_panel : Panel = null
var explorers_sprite : Sprite2D = null
var explorers_label : Label = null
var cost1_sprite : Sprite2D = null
var cost1_label : Label = null
var cost2_sprite : Sprite2D = null
var cost2_label : Label = null

var dispatch_button : Button = null
var increase_button : Button = null
var decrease_button : Button = null

var time_label : Label = null

static func new_expedition(display_name : String, resource_to_gather : String, resource_spot : ResourceSpot) -> ExpeditionOption:
	var new_option : ExpeditionOption = my_scene.instantiate()
	new_option.display_name = display_name
	new_option.resource_spot = resource_spot
	
	new_option.max_gain = get_default_gain_from_type(resource_to_gather)
	new_option.costs = get_default_costs_from_type(resource_to_gather)
	return new_option

static func get_default_gain_from_type(typeWanted : String):
	if default_gains.has(typeWanted):
		return [default_gains[typeWanted]]
	else:
		return [[typeWanted, 1.0, 1.0, Globals.blank_texture, Color.WHITE]]

static func get_default_costs_from_type(typeWanted : String) -> Array:
	var result = []
	if typeWanted == "scrap":
		result.append(default_costs["pop"])
		result.append(default_costs["clean_water"])
		result.append(default_costs["food1"])
	elif typeWanted == "clean_water":
		result.append(default_costs["pop"])
		result.append(default_costs["clean_water"].duplicate())
		result[1][1] = 2      # Increased cost for water missions
		result.append(default_costs["food1"])
	elif typeWanted == "pop":
		result.append(default_costs["pop"])
		result.append(default_costs["clean_water"].duplicate())
		result[1][1] = 4
		result.append(default_costs["food1"].duplicate())
		result[2][1] = 2
	return result

func _ready():
	name_label = get_node("NameLabel")
	gain_panel = get_node("GainPanel")
	gain_sprite = get_node("GainPanel/Sprite1")
	gain_label = get_node("GainPanel/Cost1")
	cost_panel = get_node("CostPanel")
	explorers_sprite = get_node("CostPanel/PopSprite")
	explorers_label = get_node("CostPanel/PopCost")
	cost1_sprite = get_node("CostPanel/Sprite1")
	cost1_label = get_node("CostPanel/Cost1")
	cost2_sprite = get_node("CostPanel/Sprite2")
	cost2_label = get_node("CostPanel/Cost2")
	time_label = get_node("TimeLabel")
	dispatch_button = get_node("DispatchButton")
	increase_button = get_node("AddPopButton")
	decrease_button = get_node("RemovePopButton")
	
	controller = get_parent().get_parent()
	
	dispatch_button.pressed.connect(_on_dispatch_button_pressed)
	increase_button.pressed.connect(_on_add_pop_button_pressed)
	decrease_button.pressed.connect(_on_remove_pop_button_pressed)
	
	update_full_option()

## Update the display using current cost and gain values
func update_full_option():
	time_label.text = Helpers.seconds_to_mm_ss(time_needed)
	name_label.text = display_name
	
	gain_panel.size.x = 10.0 + (max_gain.size() * width_per_cost)
	for i in range(max_gain.size()):
		var gainArray = max_gain[i] 
		if i == 0:
			gain_sprite.texture = gainArray[3]
			gain_sprite.modulate = gainArray[4]
			gain_label.text = "%d" % (gainArray[1] * pop_allocated)
		else:
			print_debug("Unused gain for expedition option")
	
	cost_panel.size.x = (costs.size() * width_per_cost)
	for i in range (costs.size()):
		var cost : Array = costs[i]
		if i == 0:
			explorers_sprite.texture = cost[2]
			explorers_sprite.modulate = cost[3]
			explorers_label.text = "%d" % (cost[1] * pop_allocated)
		elif i == 1:
			cost1_sprite.texture = cost[2]
			cost1_sprite.modulate = cost[3]
			cost1_label.text = "%d" % (cost[1] * pop_allocated)
		elif i == 2:
			cost2_sprite.texture = cost[2]
			cost2_sprite.modulate = cost[3]
			cost2_label.text = "%d" % (cost[1] * pop_allocated)
	
	if costs.size() < 3:
		cost2_sprite.hide()
		cost2_label.hide()
	elif costs.size() < 2:
		cost1_sprite.hide()
		cost1_label.hide()

func set_basic_params(display_name : String, min_pop : int, time_needed : int, travel_time : int):
	self.display_name = display_name
	self.min_pop = min_pop
	self.time_needed = time_needed
	self.travel_time = travel_time

func clear_gains():
	max_gain = []

## Set the item to be gained
func add_gain_params(resourceCollected : String, collectionChance : float, amount_per_person : float, icon_to_use : Texture2D, icon_modulate : Color):
	if costs.size() < limit_gain_items:
		max_gain.append([resourceCollected, collectionChance, amount_per_person, icon_to_use, icon_modulate])

## Remove all costs except the basic population cost
func clear_costs():
	costs = [["pop", 1, Globals.pop_texture, Color.WHITE]]

## Add a new cost
func add_cost(resourceRequired : String, cost_per_person : float, icon_texture : Texture2D, icon_modulate : Color):
	if costs.size() < limit_cost_items:
		costs.append([resourceRequired, cost_per_person, icon_texture, icon_modulate])

func _on_add_pop_button_pressed() -> void:
	if pop_allocated >= Globals.max_expedition_size:
		return
	pop_allocated += 1
	explorers_label.text = "%d" % pop_allocated
	if max_gain.size() == 1:
		gain_label.text = "%d" % (pop_allocated * max_gain[0][1])
	
	if costs.size() >= 2:
		cost1_label.text = "%d" % (pop_allocated * costs[1][1])
	if costs.size() >= 3:
		cost2_label.text = "%d" % (pop_allocated * costs[2][1])


func _on_remove_pop_button_pressed() -> void:
	if pop_allocated <= min_pop:
		return
	pop_allocated -= 1
	explorers_label.text = "%d" % pop_allocated
	if max_gain.size() == 1:
		gain_label.text = "%d" % (pop_allocated * max_gain[0][1])
	
	if costs.size() >= 2:
		cost1_label.text = "%d" % (pop_allocated * costs[1][1])
	if costs.size() >= 3:
		cost2_label.text = "%d" % (pop_allocated * costs[2][1])


func _on_dispatch_button_pressed() -> void:
	controller.dispatch_expedition(self)
