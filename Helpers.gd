extends Node

func round_to_dec(num, digit):
	return round(num * pow(10.0, digit)) / pow(10.0, digit)

## Recompute safety flags from current train stock. Call once at the end of each resource tick.
func update_resource_safety_flags(train : Train) -> void:
	for resource_type in Globals.safety_margins:
		var is_safe : bool = train.get_res(resource_type) > Globals.safety_margins[resource_type] * train.get_passenger_count() 
		var was_safe : bool = Globals.resource_safety_ok.get(resource_type, true)
		if was_safe and not is_safe:
			print("Helpers.gd:: Safety on for %s" % resource_type)
		if is_safe and not was_safe:
			print("Helpers.gd:: Safety off for %s" % resource_type)
		Globals.resource_safety_ok[resource_type] = is_safe


## Check if consumption would break safety cutoff rules using precomputed Globals.resource_safety_ok flags.
func exceeds_safety_margin(_train : Train, consume_type : String, produce_type1 : String, produce_type2 : String, _amount : float = 0.0) -> int:
	if produce_type1 == "clean_water" or produce_type2 == "clean_water":
		if consume_type == "black_water" or consume_type == "grey_water":
			return Globals.RESULT_OK

	if consume_type == "grey_water" and not Globals.resource_safety_ok.get("clean_water", true):
		return Globals.SAFETY_CUTOFF

	if Globals.safety_margins.has(consume_type) and not Globals.resource_safety_ok.get(consume_type, true):
		return Globals.SAFETY_CUTOFF

	return Globals.RESULT_OK

## Convert a [carPos,modulePos] position into a flat index value
func coords_to_index(pos2d : Array) -> int:
	return (pos2d[0] * Globals.modules_per_car) + pos2d[1]

## Convert a flat index point to a 2d array of [CarPos, modulePos]
func index_to_coords(index : int) -> Array[int]:
	var modulePos : int = index % Globals.modules_per_car
	var carPos : int = index / Globals.modules_per_car
	return [carPos, modulePos]

## Get relative xpos from train coords
func get_xpos_from_trainpos(trainPos: Array) -> float:
	var result : float = (trainPos[0] * (Globals.car_length + Globals.car_separation))
	result = result + (trainPos[1] * Globals.module_width)
	# If train front is to the right, xPos is trainStart - distance from start
	if Globals.train_direction > 0: result = result * -1
	return result

## get a trainpost [carNum, moduleNum] from a local position (Vector2)
func get_trainpos_from_coords(localPos : Vector2) -> Array[int]:
	var offset_from_start : float = 0
	offset_from_start = localPos.x
	if Globals.train_direction > 0:
		offset_from_start = offset_from_start * -1
	var carIndex : int = floor(offset_from_start / (Globals.car_length + Globals.car_separation) )
	var posInCar : int = floor(fmod(offset_from_start, (Globals.car_length + Globals.car_separation)) )
	var moduleIndex : int = floor(min((posInCar / Globals.module_width), (Globals.modules_per_car - 1)))
	return [carIndex,moduleIndex]

## Format text to 2dp or last significant figure
func pretty_print_float(value :  float) -> String:
	if  abs(value) < 1000:
		if fmod(abs(value), 1) == 0:               ## If whole number below 1k, just print it
			return "%d" % value
		elif abs(value) < 100:                     ## If fractional number below 100, print to 2dp
			return "%.2f" % value
		else:
			return "%.1f" % value    ## If fractional number below 1000, print to 1dp
	elif abs(value) < 1000000:
		return "%.2fk" % (value/1000)  ## If number below 1 million, print it as "1.01k"
	else:
		return "%.2fm" % (value/1000000) ## If number 1 million or more, print it as "1.01m"

func seconds_to_mm_ss(seconds_float: float) -> String:
	var seconds : int = floor(seconds_float)
	var minutes = seconds / 60
	var remaining_seconds = seconds % 60
	return "%02d:%02d" % [minutes, remaining_seconds]
