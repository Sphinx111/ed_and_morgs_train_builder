extends Node

var activeUI : TrainUI = null

var display_width = 1152
var display_height = 648

# Car variables
var car_length : int = 200
var car_height : int = 80
var car_separation: int = 5
var modules_per_car : int = 4

# Module Variables
var module_width : int = 50
var module_height : int = 50
var refund_module_fraction : float = 0.5

# Production ratios
var scrap_to_mech_ratio : float = 0.2 # 5 Scrap to make 1 mech parts

# Passenger Variables
var passenger_debug : bool = true
var passenger_consume_threshold : float = 0.6
var passenger_seeks_threshold : float = 0.65
var idle_wander_chance : float = 0.3    # Chance that passenger picks a random location to move to if they have no targetNeed
var aliterating_name_chance : float = .5
var need_growth_rates : Dictionary[String, float] = {
	"thirst" : 0.01,
	"hunger" : 0.005,
	"rest"   : 0.005
}
# Commenting out code contributed by junior dev (Izzy)
#,kml,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

# Minimum values to leave when doing production cycles
var safety_margins : Dictionary[String, float] = {
	"clean_water" : 50.0
}

# manifest values to help with function returns making more sense
const RESULT_OK = 0
const RESULT_FATAL = 1
const SERVICE_FINISHED = 2
const NO_RESOURCES = 3
const SAFETY_CUTOFF = 4
const USE_BOTH = 5
const USE_EITHER = 6
const CUSTOMERS_FULL = 0
const CUSTOMERS_HAS_SPACE = 1
const MODULE_REMOVED = 0
const MODULE_ADDED = 1
