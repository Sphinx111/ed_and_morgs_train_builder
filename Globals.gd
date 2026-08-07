extends Node

var activeUI : TrainUI = null

const display_width = 1152
const display_height = 648
var game_tick : int = 0

var time_factor : float = 1.0

# Car variables
const car_length : float = 200
const car_height : float = 80
const car_separation: float = 5
const modules_per_car : int = 4

var train_origin_x : float = display_width - car_length
var train_direction : int = 1
const train_initial_carriage_count : int = 3

# Module Variables
const module_width : float = 50
const module_height : float = 50
var refund_module_fraction : float = 0.5

# Production ratios
var scrap_to_mech_ratio : float = 0.2 # 5 Scrap to make 1 mech parts
var water_purification_efficiency : float = 0.9

# Passenger Variables
const passengers_initial_count : int = 4
var passenger_debug : bool = true
var passenger_consume_threshold : float = 0.6
var passenger_seeks_threshold : float = 0.65
var idle_wander_chance : float = 0.3    # Chance that passenger picks a random location to move to if they have no targetNeed
const aliterating_name_chance : float = .5
const needs_groups : Array[String] = ["thirst", "hunger", "rest"]
const work_types : Array[String] = ["any", "clean_water", "grey_water", "food1", "scrap", "mech_parts", "fuel", "oil"]
const resource_groups : Array[String] = ["clean_water", "grey_water", "black_water", "food", "scrap", "mech_parts", "oil", "fuel"]
const need_growth_rates : Dictionary[String, float] = {
	"thirst" : 0.01,
	"hunger" : 0.005,
	"rest"   : 0.005,
	"social" : 0.0,
	"illness" : 0.0
}
# Commenting out code contributed by junior dev (Izzy)
#,kml,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

## Resource storage variables
# Minimum values to leave per passenger when doing production cycles
const safety_margins : Dictionary = {
	"clean_water" : 10.0
}

## Updated at the end of each resource tick; true when the train is above the safety margin for that resource.
var resource_safety_ok : Dictionary[String, bool] = {}

# Expedition Variables
const max_expedition_size : int = 10      # Maximum passengers who can take part in an expedition

# Common icon textures to use for Sprites
const water_texture : Texture2D = preload("res://images/Water_Icon.png")
const food_texture : Texture2D = preload("res://images/food_icon.png")
const mech_parts_texture : Texture2D = preload("res://images/mech_parts_icon.png")
const scrap_texture : Texture2D = preload("res://images/scrap_icon.png")
const pop_texture : Texture2D = preload("res://images/Pop_Icon.png")
const blank_texture : Texture2D = preload("res://images/Icon_background.png")

# manifest values to help with function returns making more sense
const RESULT_OK = 0
const RESULT_FATAL = 1
const SERVICE_FINISHED = 2
const NO_RESOURCES = 3
const SAFETY_CUTOFF = 4
const USE_BOTH = 5
const USE_EITHER = 6
const EXCEEDS_MAX_SPEED = 7
const CUSTOMERS_FULL = 0
const CUSTOMERS_HAS_SPACE = 1
const WORKERS_FULL = 0
const WORKERS_HAS_SPACE = 1
const MODULE_REMOVED = 0
const MODULE_ADDED = 1
