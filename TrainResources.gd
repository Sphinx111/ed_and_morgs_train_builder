extends RefCounted

class_name TrainResources

## Owns a train's resource storage (amounts, storage caps, mothball state) and its per-tick
## production/consumption tracking (exact single-tick figures, a rolling window, and the
## at-a-glance trend derived from that window). Train.gd composes one of these (its
## resourceManager field) instead of holding this state/behaviour itself - see Train.gd's
## resource_tick() for how begin_tick()/end_tick() bracket the carriage/module/passenger ticks
## that actually cause resource changes via get_res()/add_res()/gather_res() below.
##
## "pop" is handled here too, even though it isn't stored in `res` - it's backed by the train's
## PassengerManager - because callers (UI, TrainEventProcessor) treat it as just another
## resource key, and keeping that illusion consistent here avoids a special case everywhere else.

var train : Train

# x varieties of food
var res : Dictionary[String, float] = {
	"food" : 100.0,
	"food1" : 100.0,
	"food2" : 100.0,
	"food3" : 0.0,
	"food4" : 0.0,
	"food5" : 0.0,
	"food6" : 0.0,
	"clean_water" : 200.0,
	"grey_water" : 0.0,
	"black_water" : 0.0,
	"mech_parts" : 100.0,
	"fuel" : 100.0,
	"oil" : 10.0,
	"fertiliser" : 10.0,
	"seeds1" : 10.0,
	"seeds2" : 10.0,
	"seeds3" : 0.0,
	"seeds4" : 0.0,
	"seeds5" : 0.0,
	"seeds6" : 0.0,
	"scrap" : 0.0
}

var max_res : Dictionary = {}

# Whether each producible resource's industry is mothballed (true = not producing new cycles).
var industry_states : Dictionary[String, bool] = {}

# Accumulates the gross amount produced and gross amount consumed of each resource
# across the resource tick currently in progress. Reset by begin_tick().
var _tick_produced : Dictionary[String, float] = {}
var _tick_consumed : Dictionary[String, float] = {}
# Ignore float noise smaller than this when deciding whether a resource moved at all.
const TICK_DELTA_EPSILON : float = 0.0001

## Gross amount of each resource produced / consumed over the most recently completed
## resource tick (both values are >= 0; a resource missing from a dictionary produced or
## consumed none that tick). Populated by end_tick(); read by the UI to show exact single-tick
## production/consumption figures.
var last_tick_produced : Dictionary[String, float] = {}
var last_tick_consumed : Dictionary[String, float] = {}

## Net trend for each resource, driven by the rolling window sums below (rolling_tick_produced /
## rolling_tick_consumed) rather than the raw single-tick numbers above, so a single noisy or
## bursty tick can't flip it back and forth - a wide window rides out production that arrives in
## periodic batches rather than a steady trickle: 1 = producing more than consuming, -1 =
## consuming more than producing, 0/absent = net unchanged over the window. Read by the UI for
## the at-a-glance trend arrows.
var last_tick_trend : Dictionary[String, int] = {}

# Every resource key that has ever produced or consumed anything, so a resource that goes quiet
# still gets a zero folded into its rolling window (instead of the window getting stuck on
# whatever the last nonzero tick left it at). Added to by _track_res_delta().
var _tracked_resource_keys : Dictionary[String, bool] = {}

## Number of past ticks kept in the rolling production/consumption window (see
## rolling_tick_produced / rolling_tick_consumed below). ROLLING_WINDOW_SIZE *
## Globals.tick_duration is the window's length in seconds of real time.
const ROLLING_WINDOW_SIZE : int = 60
# Fixed-size ring buffers of per-tick produced/consumed amounts, one slot per tick. All
# resources share one write cursor (_rolling_index) since every resource advances exactly one
# slot per tick; buffers are created lazily, zero-filled, the first time a resource is tracked.
var _rolling_produced_buffer : Dictionary[String, Array] = {}
var _rolling_consumed_buffer : Dictionary[String, Array] = {}
var _rolling_index : int = 0

## Sum of the last ROLLING_WINDOW_SIZE ticks' produced/consumed amounts per resource, i.e. a
## "sustained" figure that doesn't jump around from tick to tick. Maintained incrementally in
## O(1) per tick per resource (add the new sample, subtract the one falling out of the window)
## rather than re-summing the ring buffer on every read. Read by the UI for detailed displays,
## and also drives last_tick_trend above so the arrow always agrees with these numbers.
var rolling_tick_produced : Dictionary[String, float] = {}
var rolling_tick_consumed : Dictionary[String, float] = {}


func _init(owning_train : Train) -> void:
	train = owning_train


func get_res(key : String) -> float:
	if res.has(key):
		return res.get(key)
	if key == "pop":
		if train.passengerManager != null:
			return train.passengerManager.passengers.size()
		return 0
	return 0


## Function to consume amount if available, returns a status code
func gather_res(key : String, amount : float) -> int:
	if res.has(key) and res[key] >= amount:
		add_res(key, -amount)
		return Globals.RESULT_OK
	return Globals.NO_RESOURCES


# adds a resource, returning the amount that could not be added
func add_res(key : String, amount : float) -> float:
	if res.has(key):
		var before : float = res[key]
		if max_res.has(key):
			var goal_amount : float = res[key] + amount
			if goal_amount > max_res[key]:
				var excess : float = goal_amount - max_res[key]
				res[key] = max_res[key];
				_track_res_delta(key, res[key] - before)
				return excess
			else:
				res[key] = res[key] + amount
		_track_res_delta(key, res[key] - before)
	elif key == "pop":
		for i in range(roundi(amount)):
			train.passengerManager.add_passenger()
	else:
		print_debug("adding resource that doesn't exist: " + key)
	return 0


func add_pop(amount : int) -> void:
	if amount > 0:
		for i in range(amount):
			train.passengerManager.add_passenger()
		_track_res_delta("pop", amount)
	else:
		for i in range(abs(amount)):
			remove_random_passenger()


func remove_random_passenger() -> void:
	train.passengerManager.remove_random_passenger()
	_track_res_delta("pop", -1)


## Record a change to a resource amount, made during the resource tick currently in
## progress, so the exact production/consumption totals for the tick can be worked out
## afterwards. Positive deltas accumulate into produced, negative into consumed.
func _track_res_delta(key : String, delta : float) -> void:
	if delta == 0.0:
		return
	_tracked_resource_keys[key] = true
	if delta > 0.0:
		_tick_produced[key] = _tick_produced.get(key, 0.0) + delta
	else:
		_tick_consumed[key] = _tick_consumed.get(key, 0.0) + (-delta)


func amend_storage(type : String, amount : float) -> void:
	if max_res.has(type):
		max_res[type] = max_res[type] + amount
	else:
		max_res[type] = amount


func is_industry_mothballed(type_name : String) -> bool:
	return industry_states.get(type_name, false)


func set_industry_mothballed(type_name : String, mothballed : bool) -> void:
	industry_states[type_name] = mothballed


## Reset this tick's produced/consumed accumulators. Call once at the start of a resource tick,
## before anything (carriages, modules, passengers) has had a chance to add/remove resources.
func begin_tick() -> void:
	_tick_produced.clear()
	_tick_consumed.clear()


## Publish this tick's exact produced/consumed totals, fold the tick into each tracked
## resource's rolling window, and derive the at-a-glance +1/-1/0 trend from the rolling window's
## net. Call once at the end of a resource tick, after everything that could have changed a
## resource this tick has run. Iterates every resource ever tracked - not just ones touched this
## tick - so a resource that's gone quiet still gets a zero folded into its window, rather than
## the window getting stuck on its last nonzero tick.
func end_tick() -> void:
	last_tick_produced.clear()
	last_tick_consumed.clear()
	last_tick_trend.clear()
	for key in _tracked_resource_keys:
		var produced : float = _tick_produced.get(key, 0.0)
		var consumed : float = _tick_consumed.get(key, 0.0)
		last_tick_produced[key] = produced
		last_tick_consumed[key] = consumed
		_record_rolling_sample(key, produced, consumed)

		var rolling_produced : float = rolling_tick_produced.get(key, 0.0)
		var rolling_consumed : float = rolling_tick_consumed.get(key, 0.0)
		var net : float = rolling_produced - rolling_consumed
		if net > TICK_DELTA_EPSILON:
			last_tick_trend[key] = 1
		elif net < -TICK_DELTA_EPSILON:
			last_tick_trend[key] = -1
	_rolling_index = (_rolling_index + 1) % ROLLING_WINDOW_SIZE


## Write this tick's sample into resource `key`'s ring-buffer slot and update its rolling sums
## in O(1): add the new sample, subtract whatever sample it's overwriting (the one from
## ROLLING_WINDOW_SIZE ticks ago). Creates the (zero-filled) buffers the first time `key` is seen.
func _record_rolling_sample(key : String, produced : float, consumed : float) -> void:
	if not _rolling_produced_buffer.has(key):
		_rolling_produced_buffer[key] = _new_rolling_buffer()
		_rolling_consumed_buffer[key] = _new_rolling_buffer()
		rolling_tick_produced[key] = 0.0
		rolling_tick_consumed[key] = 0.0

	var produced_buffer : Array = _rolling_produced_buffer[key]
	var consumed_buffer : Array = _rolling_consumed_buffer[key]

	var old_produced : float = produced_buffer[_rolling_index]
	var old_consumed : float = consumed_buffer[_rolling_index]
	produced_buffer[_rolling_index] = produced
	consumed_buffer[_rolling_index] = consumed

	var produced_sum : float = rolling_tick_produced.get(key, 0.0)
	var consumed_sum : float = rolling_tick_consumed.get(key, 0.0)
	rolling_tick_produced[key] = produced_sum - old_produced + produced
	rolling_tick_consumed[key] = consumed_sum - old_consumed + consumed


func _new_rolling_buffer() -> Array:
	var buffer : Array = []
	buffer.resize(ROLLING_WINDOW_SIZE)
	buffer.fill(0.0)
	return buffer
