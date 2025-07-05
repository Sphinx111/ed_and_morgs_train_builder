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
