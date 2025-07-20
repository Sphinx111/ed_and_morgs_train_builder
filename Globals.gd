extends Node

var activeUI : TrainUI = null

var display_width = 1152
var display_height = 648
var game_tick : int = 0

var time_factor : float = 1.0

# Car variables
var car_length : float = 200
var car_height : float = 80
var car_separation: float = 5
var modules_per_car : int = 4

var train_origin_x = display_width - car_length
var train_direction = 1
var train_initial_carriage_count = 3

# Module Variables
var module_width : float = 50
var module_height : float = 50
var refund_module_fraction : float = 0.5

# Production ratios
var scrap_to_mech_ratio : float = 0.2 # 5 Scrap to make 1 mech parts
var water_purification_efficiency : float = 0.9

# Passenger Variables
var passenger_debug : bool = true
var passenger_consume_threshold : float = 0.6
var passenger_seeks_threshold : float = 0.65
var idle_wander_chance : float = 0.3    # Chance that passenger picks a random location to move to if they have no targetNeed
var aliterating_name_chance : float = .5
var need_growth_rates : Dictionary[String, float] = {
	"thirst" : 0.01,
	"hunger" : 0.005,
	"rest"   : 0.005,
	"social" : 0.0,
	"illness" : 0.0
}
# Commenting out code contributed by junior dev (Izzy)
#,kml,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

# Resource storage variables
# Minimum values to leave when doing production cycles
var safety_margins : Dictionary[String, float] = {
	"clean_water" : 50.0
}

# Expedition Variables
var max_expedition_size = 10      # Maximum passengers who can take part in an expedition

# Common icon textures to use for Sprites
const water_texture : Texture2D = preload("res://images/Water_Icon.png")
const food_texture : Texture2D = preload("res://images/food_icon.png")
const mech_parts_texture : Texture2D = preload("res://images/mech_parts_icon.png")
const scrap_texture : Texture2D = preload("res://images/scrap_icon.png")
const pop_texture : Texture2D = preload("res://images/Pop_Icon.png")

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
