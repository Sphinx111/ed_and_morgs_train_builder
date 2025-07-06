extends Node

func round_to_dec(num, digit):
	return round(num * pow(10.0, digit)) / pow(10.0, digit)

func exceeds_safety_margin(type : String, amount : float = 0.0) -> int:	# compare a resource to the margins and return SAFETY_CUTOFF if amount is below margin
	if Globals.safety_margins.has(type):
		if amount > Globals.safety_margins.get(type):
			return Globals.RESULT_OK
		else:
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
