extends Node

class_name ServiceProvider

var trigger_once : bool = false	## Set to true if the module should only be used once per visit (ie a Shower in cabin)

var outputType : String  = ""	## The type of need to be served
var outputRate : float = 0.0	## Base rate to provide output Need

var inputType1 : String = ""
var input1_needed : float = 0.0  ## Amount of input type 1 to produce 1.0 output amount

var inputType2 : String = ""	## Only set this if there is an inputType1
var input2_needed : float = 0.0  ## Amount of input type 2 to produce 1.0 output amount

var wasteType1 : String = ""
var waste1_produced : float = 0.0	## Amount of waste produced for 1 unit of needs

func init() -> void:
	pass

func serve_customer(customer : Passenger, train : Train, module : ModuleBase) -> int:
	var amount_wanted = 1.0

	# If this service provides a need, check if customer needs it, and apply service Rate
	if outputType != "":
		amount_wanted = customer.wants_need(outputType)
		if amount_wanted == 0.0:
			return Globals.SERVICE_FINISHED
		
		amount_wanted = min(amount_wanted, outputRate)	# Limit the amount to the rate of the service
		amount_wanted = amount_wanted * module.service_speed_modifier	# Apply any modifiers from module

	var percent_to_fulfill = 1.0

	# Check how much of the input needed can be fulfilled by train
	if inputType1 != "":
		percent_to_fulfill = _calc_input1_success(train, amount_wanted)
		if inputType2 != "":
			var input2_percent = _calc_input2_success(train, amount_wanted)
			if input2_percent < percent_to_fulfill:
				percent_to_fulfill = input2_percent
	
	# If the train can't meet the input requirements, give up
	if percent_to_fulfill == 0.0:
		return Globals.NO_RESOURCES
	
	_spend_resources(train, percent_to_fulfill, amount_wanted)
	_output_waste(train, percent_to_fulfill, amount_wanted)
	var remaining_need = customer.adjust_need(outputType, amount_wanted * percent_to_fulfill)
	
	if remaining_need == 0.0:
		return Globals.SERVICE_FINISHED
	else:
		return Globals.RESULT_OK


## Calculate how much of input1 to spend based on the amount of need to fulfill.
## and Reduce the amount if the train can only partly fill the need
func _calc_input1_success(train : Train, amount_wanted : float) -> float:
	var res_available = train.get_res(inputType1)
	var res_wanted = amount_wanted * input1_needed
	var percent_of_request_to_fulfill = min((res_available / res_wanted), 1)

	return percent_of_request_to_fulfill


## Calculate how much of input2 to spend based on amount of need to fulfill.
## and Reduce the amount if the train can only partly fill the need
func _calc_input2_success(train : Train, amount_wanted : float) -> float:
	var res_available = train.get_res(inputType2)
	var res_wanted = amount_wanted * input2_needed
	var percent_of_request_to_fulfill = min((res_available / res_wanted), 1)

	return percent_of_request_to_fulfill

## Spend any resources needed
func _spend_resources(train : Train, percent_to_spend : float, amount_served : float):
	if inputType1 != "":
		train.add_res(inputType1, -1 * input1_needed * percent_to_spend * amount_served)
		if inputType2 != "":
			train.add_res(inputType2, -1 * input1_needed * percent_to_spend * amount_served)


## If provider produces waste during service, add it to the train
func _output_waste(train : Train, percent_to_produce : float, amount_served : float):
	if wasteType1 != "":
		train.add_res(wasteType1, waste1_produced * percent_to_produce * amount_served)
