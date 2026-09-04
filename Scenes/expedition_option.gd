extends Panel

class_name ExpeditionOption
## This class holds variables for an expedition, and controls how it displays in the Expeditions Tracker
@export var display_name : String = "Collect Scrap"

const my_scene = preload("res://Scenes/expedition_option.tscn")

var controller : ExpeditionsController = null

var min_pop : int = 2        ## Minimum number of people required for expedition
var travel_time : int = 60
var collection_time : int = 30
var scavenge_time : int = 60
var resource_spot : MapResourceContainer = null
var is_scavenge : bool = false
var is_train_car_recovery : bool = false
var scavenge_location : MapLocation = null

# List of resources which can be gained from the expedition
#  [resource name, amount, chance to find, texture to use, and icon color modulate]
var gains_per_pop : Array = [_build_gain_row("scrap", 25)]

const default_gains : Dictionary = {
	"clean_water" : {"amount" : 10, "chance" : 1.0},
	"scrap": {"amount": 25, "chance": 1.0},
	"grey_water": {"amount": 15, "chance": 1.0},
	"pop": {"amount": 2, "chance": 1.0},
	"oil": {"amount": 10, "chance": 1.0},
	"mech_parts": {"amount": 5, "chance": 1.0},
	"food1": {"amount": 10, "chance": 1.0},
}

# List of resources per person if not using the default costs in default_costs
#  [resource name, amount, texture to use, icon color modulate]
var costs : Array = [
	_build_cost_row("pop", 1),
	_build_cost_row("clean_water", 2),
	_build_cost_row("food1", 1),
]

const default_cost_amounts : Dictionary = {
	"pop": 1,
	"clean_water": 2,
	"food1": 1,
}

# Tracking variables
var pop_allocated : int = 2

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

static func _build_gain_row(type_name: String, amount: float, chance: float = 1.0) -> Array:
	var resource_type : ResourceType = ResourceTypeRegistry.get_type(type_name)
	return [type_name, amount, chance, resource_type.iconTexture, resource_type.iconModulate]


static func _build_cost_row(type_name: String, amount: float) -> Array:
	var resource_type := ResourceTypeRegistry.get_type(type_name)
	return [type_name, amount, resource_type.iconTexture, resource_type.iconModulate]


static func new_expedition(resource_to_gather: String, _resource_spot: MapResourceContainer) -> ExpeditionOption:
	var new_option : ExpeditionOption = my_scene.instantiate()
	new_option.display_name = ResourceTypeRegistry.get_type(resource_to_gather).display_name
	new_option.resource_spot = _resource_spot
	
	new_option.gains_per_pop = get_default_gain_from_type(resource_to_gather)
	new_option.costs = get_default_costs_from_type(resource_to_gather)
	return new_option

static func new_scavenge_expedition(location : MapLocation) -> ExpeditionOption:
	var new_option : ExpeditionOption = my_scene.instantiate()
	new_option.display_name = ResourceTypeRegistry.get_type("unknown").display_name
	new_option.is_scavenge = true
	new_option.scavenge_location = location
	new_option.gains_per_pop = [_build_gain_row("unknown", 0)]
	new_option.costs = get_default_costs_from_type("scrap")
	return new_option


static func new_train_car_expedition(_resource_spot: MapResourceContainer) -> ExpeditionOption:
	var new_option : ExpeditionOption = my_scene.instantiate()
	new_option.display_name = "Recover Train Car"
	new_option.resource_spot = _resource_spot
	new_option.is_train_car_recovery = true
	new_option.travel_time = 0
	new_option.gains_per_pop = [_build_gain_row("trainCars", 1)]
	new_option.costs = get_default_costs_from_type("scrap")
	return new_option

static func get_default_gain_from_type(type_wanted : String) -> Array:
	if default_gains.has(type_wanted):
		var gain_data: Dictionary = default_gains[type_wanted]
		return [_build_gain_row(type_wanted, gain_data.amount, gain_data.chance)]
	return [_build_gain_row(type_wanted, 1.0)]

static func get_default_costs_from_type(type_wanted : String) -> Array:
	var result: Array = []
	match type_wanted:
		"grey_water":
			result.append(_build_cost_row("pop", default_cost_amounts["pop"]))
			result.append(_build_cost_row("clean_water", 2))
			result.append(_build_cost_row("food1", default_cost_amounts["food1"]))
		"pop":
			result.append(_build_cost_row("pop", default_cost_amounts["pop"]))
			result.append(_build_cost_row("clean_water", 4))
			result.append(_build_cost_row("food1", 2))
		"oil":
			result.append(_build_cost_row("pop", default_cost_amounts["pop"]))
			result.append(_build_cost_row("clean_water", default_cost_amounts["clean_water"]))
			result.append(_build_cost_row("food1", 2))
		_:
			result.append(_build_cost_row("pop", default_cost_amounts["pop"]))
			result.append(_build_cost_row("clean_water", default_cost_amounts["clean_water"]))
			result.append(_build_cost_row("food1", default_cost_amounts["food1"]))
	return result

func get_train_car_gather_time(pop_count: int) -> int:
	return maxi(1, MapResourceLocation.GATHER_TIME / pop_count)

func get_activity_time() -> int:
	if is_scavenge:
		return scavenge_time
	if is_train_car_recovery:
		return get_train_car_gather_time(pop_allocated)
	return collection_time

func get_total_duration() -> int:
	return (2 * travel_time) + get_activity_time()

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
	
	update_full_option()

## Update the display using current cost and gain values
func update_full_option():
	time_label.text = Helpers.seconds_to_mm_ss(get_total_duration())
	name_label.text = display_name
	
	gain_panel.size.x = 10.0 + (gains_per_pop.size() * width_per_cost)
	for i in range(gains_per_pop.size()):
		var gain_array = gains_per_pop[i]
		if i == 0:
			_apply_resource_icon(gain_sprite, gain_array[0])
			if is_scavenge or is_train_car_recovery:
				gain_label.text = "?"
			else:
				var max_gain : float = min(resource_spot.amount, gain_array[1] * pop_allocated)
				gain_label.text = ResourceTypeRegistry.format_amount(gain_array[0], max_gain)
		else:
			print_debug("Unused gain for expedition option")
	
	cost_panel.size.x = (costs.size() * width_per_cost)
	for i in range (costs.size()):
		var cost : Array = costs[i]
		if i == 0:
			_apply_resource_icon(explorers_sprite, cost[0])
			explorers_label.text = ResourceTypeRegistry.format_amount(cost[0], cost[1] * pop_allocated)
		elif i == 1:
			_apply_resource_icon(cost1_sprite, cost[0])
			cost1_label.text = ResourceTypeRegistry.format_amount(cost[0], cost[1] * pop_allocated)
		elif i == 2:
			_apply_resource_icon(cost2_sprite, cost[0])
			cost2_label.text = ResourceTypeRegistry.format_amount(cost[0], cost[1] * pop_allocated)
	
	if costs.size() < 3:
		cost2_sprite.hide()
		cost2_label.hide()
	elif costs.size() < 2:
		cost1_sprite.hide()
		cost1_label.hide()


func _apply_resource_icon(sprite: Sprite2D, type_name: String) -> void:
	var resource_type := ResourceTypeRegistry.get_type(type_name)
	sprite.texture = resource_type.iconTexture
	sprite.modulate = resource_type.iconModulate


func set_basic_params(
	_display_name : String,
	_min_pop : int,
	_travel_time : int,
	_collection_time : int = 30,
	_scavenge_time : int = 60
):
	self.display_name = _display_name
	self.min_pop = _min_pop
	self.travel_time = _travel_time
	self.collection_time = _collection_time
	self.scavenge_time = _scavenge_time

func _refresh_time_label() -> void:
	time_label.text = Helpers.seconds_to_mm_ss(get_total_duration())

func _on_add_pop_button_pressed() -> void:
	if pop_allocated >= Globals.max_expedition_size:
		return
	pop_allocated += 1
	explorers_label.text = ResourceTypeRegistry.format_amount("pop", pop_allocated)
	if gains_per_pop.size() == 1:
		if is_scavenge or is_train_car_recovery:
			gain_label.text = "?"
		else:
			var max_gain : float = min(resource_spot.amount, gains_per_pop[0][1] * pop_allocated)
			gain_label.text = ResourceTypeRegistry.format_amount(gains_per_pop[0][0], max_gain)
	
	if costs.size() >= 2:
		cost1_label.text = ResourceTypeRegistry.format_amount(costs[1][0], pop_allocated * costs[1][1])
	if costs.size() >= 3:
		cost2_label.text = ResourceTypeRegistry.format_amount(costs[2][0], pop_allocated * costs[2][1])
	if is_train_car_recovery:
		_refresh_time_label()


func _on_remove_pop_button_pressed() -> void:
	if pop_allocated <= min_pop:
		return
	pop_allocated -= 1
	explorers_label.text = ResourceTypeRegistry.format_amount("pop", pop_allocated)
	if gains_per_pop.size() == 1:
		if is_scavenge or is_train_car_recovery:
			gain_label.text = "?"
		else:
			var max_gain : float = min(resource_spot.amount, gains_per_pop[0][1] * pop_allocated)
			gain_label.text = ResourceTypeRegistry.format_amount(gains_per_pop[0][0], max_gain)
	
	if costs.size() >= 2:
		cost1_label.text = ResourceTypeRegistry.format_amount(costs[1][0], pop_allocated * costs[1][1])
	if costs.size() >= 3:
		cost2_label.text = ResourceTypeRegistry.format_amount(costs[2][0], pop_allocated * costs[2][1])
	if is_train_car_recovery:
		_refresh_time_label()


func _on_dispatch_button_pressed() -> void:
	controller.dispatch_expedition(self)
