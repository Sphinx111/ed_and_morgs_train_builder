extends Node

# Car variables
var car_length : int = 200
var car_height : int = 80
var car_separation: int = 5
var modules_per_car : int = 4

# Module Variables
var module_width : int = 50
var module_height : int = 50


# Passenger Variables
var passenger_debug : bool = true
var passenger_consume_threshold : float = 0.6
var passenger_seeks_threshold : float = 0.65
var idle_wander_chance : float = 0.3    # Chance that passenger picks a random location to move to if they have no targetNeed
var aliterating_name_chance : float = .5
# Commenting out code contributed by junior dev (Izzy)
#,kml,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

# misc variable
var minimum_water_safety_margin : int = 10

# manifest values to help with function returns making more sense
const result_ok = 0
const result_fatal = 1
