extends RefCounted

class_name PassengerNeeds

## Owns a passenger's need levels (thirst, hunger, rest, illness, social), their caps, and the
## currently-targeted need - the tracking Passenger.gd used to hold directly. Passenger composes
## one of these (its needsManager field) and keeps thin pass-through methods for the handful of
## needs-related calls other systems (ServiceProvider, PassengerManager, PassengerPanel) make on
## a passenger, so those callers don't need to reach into needsManager directly.
##
## Needs growth and threshold-checking are still driven from here, but they read temperature/
## tolerance fields off the owning passenger and call back into it (hit_max_need,
## check_current_module, exit_worker_module, is_dying) for anything that isn't purely about the
## need levels themselves - same back-reference pattern as TrainResources uses on Train.

var passenger : Passenger

var needs : Dictionary[String, float] = {
	"thirst" : 0.0,
	"hunger" : 0.65,
	"rest" : 0.0,
	"illness" : 0.0,
	"social" : 0.0
}
const maxNeeds : Dictionary[String, float] = {
	"thirst" : 1.0,
	"hunger" : 1.0,
	"rest" : 1.0,
	"illness" : 1.0,
	"social" : 99.0
}

## Which need (if any) the passenger is currently prioritising and heading toward a module for.
var targetNeed : String = ""

## Need proportion (0-1 of max) at which a need becomes noteworthy enough for the passenger to
## think about it, even before it's urgent enough to act on (Globals.passenger_seeks_threshold is
## the higher bar for actually acting). Kept as its own constant so it can be retuned separately.
const NEED_THOUGHT_THRESHOLD : float = 0.75

# Which needs were already at/above NEED_THOUGHT_THRESHOLD as of the last check_needs() call, so
# a need sitting above the threshold triggers one thought when it crosses, not one every tick it
# stays there.
var _needs_past_thought_threshold : Dictionary[String, bool] = {}


func _init(owning_passenger : Passenger) -> void:
	passenger = owning_passenger


func randomize_needs() -> void:
	for key in needs:
		needs[key] = randf_range(0.0, 0.5)


func wants_need(type : String) -> float:
	if needs.has(type):
		return (needs[type])
	return 0.0


# adjust the need, and return the amount remaining
func adjust_need(type : String, amount : float) -> float:
	needs[type] = max(needs[type] - amount, 0)
	return needs[type]


func get_need_proportion(need_key: String) -> float:
	if not needs.has(need_key) or not maxNeeds.has(need_key):
		return 0.0
	var cap := maxNeeds[need_key]
	if cap <= 0.0:
		return 0.0
	return needs[need_key] / cap


## Used before passengers are sent on an expedition
func fix_all_needs() -> void:
	for key in needs.keys():
		needs[key] = 0.0


func format_needs_summary() -> String:
	var parts: PackedStringArray = []
	for key in needs.keys():
		parts.append("%s=%.3f" % [key, needs[key]])
	return ", ".join(parts)


## Grow every need by its per-tick rate; thirst grows faster the hotter the train is running
## above base temperature, scaled by the passenger's own heat tolerance.
func grow_needs(train_temperature: float) -> void:
	for key in needs.keys():
		if key == "thirst":
			var temp_stress : float = train_temperature - Globals.train_base_temp
			needs[key] += (Globals.need_growth_rates[key] * temp_stress / passenger.temp_stress_tolerance * passenger.water_consumption_at_tolerance)
		else:
			needs[key] += Globals.need_growth_rates[key]


## If any need has hit its cap, ask the passenger to react (which may be fatal, via
## hit_max_need); otherwise pick the highest-proportion need as the new target once it crosses
## the seek threshold, and have the passenger react to the new target (head for a module that
## serves it, stop working if it was working). Along the way: a thought fires the tick the
## passenger's targeted need changes, and another fires the tick any need first crosses
## NEED_THOUGHT_THRESHOLD - both edge-triggered so a need sitting still doesn't spam thoughts.
func check_needs() -> void:
	if passenger.is_on_expedition == true:
		return
	var highest_proportion := 0.0
	var priority_need := ""
	for key in needs.keys():
		if not maxNeeds.has(key) or maxNeeds[key] <= 0.0:
			continue
		if needs[key] >= maxNeeds[key]:
			if passenger.hit_max_need(key) == Globals.RESULT_FATAL:
				passenger.is_dying = true
				return
		var proportion := get_need_proportion(key)
		_check_thought_threshold(key, proportion)
		if proportion > highest_proportion:
			highest_proportion = proportion
			priority_need = key
	if highest_proportion > Globals.passenger_seeks_threshold:
		if priority_need != "":
			if priority_need != targetNeed:
				targetNeed = priority_need
				passenger.emit_thought(PassengerThought.TYPE_NEEDS, PassengerThought.SENTIMENT_NEGATIVE, "I really need to sort out my %s" % priority_need, priority_need)
			passenger.check_current_module()
			if passenger.is_working and passenger.is_in_module:
				passenger.exit_worker_module()


## Fires a "needs" thought the first tick a need's proportion crosses NEED_THOUGHT_THRESHOLD, and
## clears the flag once it drops back below so a later re-crossing can fire again.
func _check_thought_threshold(need_key : String, proportion : float) -> void:
	var was_past : bool = _needs_past_thought_threshold.get(need_key, false)
	var is_past : bool = proportion >= NEED_THOUGHT_THRESHOLD
	if is_past and not was_past:
		passenger.emit_thought(PassengerThought.TYPE_NEEDS, PassengerThought.SENTIMENT_NEGATIVE, "My %s is really bothering me now" % need_key, need_key)
	_needs_past_thought_threshold[need_key] = is_past
