extends Node

class_name ProductionProvider

var cycleTime      : int = 1             ## Number of resource ticks to complete a production cycle
var progress : float     = 0.0           ## Helper variable to track progress towards production

var outputType1    : String  = ""	## The type of resource to produce
var output1_amount : float = 0.0      ## Amount of resource to produce each cycle

var outputType2    : String  = ""	## Only set this if there is an outputType1
var output2_amount : float = 0.0      ## Amount of resource to produce each cycle

var input_mode : int = Globals.USE_BOTH	## Defines whether to use both resources at once, or prioritise first input type

var inputType1 : String = ""	## Type of resource required to produce
var input1_needed : float = 0.0     ## Amount of input type 1 to begin a production cycle
var input1_from_map : bool = false  ## true if resource is taken from world map instead of train
var max_speed : float = -1         ## If train speed is above this value, module does not produce

var inputType2 : String = ""	## Only set this if there is an inputType1
var input2_needed : float = 0.0     ## Amount of input type 2 to begin a production cycle

## Set up the Production Provider's variables
func init() -> void:
	pass

## Return array of Strings representing type of work done in module
func get_work_types() -> Array[String]:
	if outputType1 != "" and outputType2 != "":
		return [outputType1, outputType2]
	elif outputType1 != "":
		return [outputType1]
	return []

## Control function to call each resource tick, must provide MapHandler if resource comes from map
func produce(train : Train, worker_modifier : float) -> int:
	var result = Globals.RESULT_OK

	if progress == 0.0:
		if input_mode == Globals.USE_BOTH:
			result = start_cycle_both(train, worker_modifier)	# Might indicate insufficient resources
		elif input_mode == Globals.USE_EITHER:
			result = start_cycle_either(train, worker_modifier)
	if progress > 0.0 and progress < 1.0:
		make_progress(train, worker_modifier)
	if progress >= 1.0:
		finish_cycle(train)
	
	return result

## Consumes resources and starts cycle
func start_cycle_both(train : Train, worker_modifier : float) -> int:
	var result = Globals.RESULT_OK

	if max_speed >= 0 and train.speed > max_speed:
		return Globals.EXCEEDS_MAX_SPEED

	if inputType1 != "" :
		var input1_avail = train.get_res(inputType1)
		if input1_from_map == false:
			result = Helpers.exceeds_safety_margin(train, inputType1, outputType1, outputType2, input1_needed)
			if input1_avail < input1_needed:
				result = Globals.NO_RESOURCES
				if result == Globals.RESULT_OK and inputType2 != "":
					var input2_avail = train.get_res(inputType2)
					result = Helpers.exceeds_safety_margin(train, inputType1, outputType1, outputType2, input1_needed)
					if input2_avail < input2_needed:
						result = Globals.NO_RESOURCES
		elif input1_from_map == true:       # if input1 is from the map, it consumes it at this step
			result = train.worldMap.gather_resource(inputType1, input1_needed)

	if result == Globals.RESULT_OK:
		if input1_from_map == false and inputType1 != "":
			train.add_res(inputType1, -1 * input1_needed)
			if inputType2 != "":
				train.add_res(inputType2, -1 * input2_needed)
		progress = progress + (worker_modifier / cycleTime)
	
	return result

## Consumes resources and starts cycle
func start_cycle_either(train : Train, worker_modifier : float) -> int:
	var result = Globals.RESULT_OK
	
	if max_speed >= 0 and train.speed > max_speed:
		return Globals.EXCEEDS_MAX_SPEED
	
	if inputType1 != "" :
		var input1_avail = train.get_res(inputType1)
		if input1_from_map == false:
			result = Helpers.exceeds_safety_margin(train, inputType1, outputType1, outputType2, input1_needed)
			if input1_avail < input1_needed:
				result = Globals.NO_RESOURCES
		elif input1_from_map == true:       # if input1 is from the map, it consumes it at this step
			result = train.worldMap.gather_resources(inputType1, input1_needed)

	if result == Globals.RESULT_OK:
		if input1_from_map == false and inputType1 != "":
			train.add_res(inputType1, -1 * input1_needed)
		progress = progress + (1.0 / cycleTime)
		return Globals.RESULT_OK

	# Only consume resource2 if resource1 is not available
	if result != Globals.RESULT_OK:
		if inputType2 != "":
			result = Helpers.exceeds_safety_margin(train, inputType1, outputType1, outputType2, input1_needed)
			var input2_avail = train.get_res(inputType2)
			if input2_avail < input2_needed:
				result = Globals.NO_RESOURCES

	if result == Globals.RESULT_OK:
		if inputType2 != "":
			train.add_res(inputType2, -1 * input2_needed)
		progress = progress + (worker_modifier / cycleTime)
	
	return result



func make_progress(train : Train, worker_modifier : float):
	# Don't make progress if train is above max speed for this module (ie scrap arms)
	if max_speed >= 0 and train.speed > max_speed:
		return
	progress = progress + (worker_modifier / cycleTime)

func finish_cycle(train : Train):
	progress = 0.0
	if outputType1 != "":
		if outputType1 == "pop":
			train.passengerManager.add_passenger()
			return
		train.add_res(outputType1, output1_amount)
		if outputType2 != "":
			train.add_res(outputType2, output2_amount)
