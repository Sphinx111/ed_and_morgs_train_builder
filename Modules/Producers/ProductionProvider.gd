extends RefCounted

class_name ProductionProvider

var cycleTime: int = 1
var progress: float = 0.0
var carryOver: float = 0.0

var outputType1: String = ""
var output1_amount: float = 0.0
var output1_backlog: float = 0.0

var outputType2: String = ""
var output2_amount: float = 0.0
var output2_backlog: float = 0.0

var input_mode: ProductionRecipe.UsageMode = ProductionRecipe.UsageMode.BOTH

var inputType1: String = ""
var input1_needed: float = 0.0
var input1_from_map: bool = false
var max_speed: float = -1.0

var inputType2: String = ""
var input2_needed: float = 0.0


static func from_recipe(recipe: ProductionRecipe) -> ProductionProvider:
	var producer := ProductionProvider.new()
	producer.cycleTime = recipe.cycle_time
	producer.input_mode = recipe.input_mode
	producer.inputType1 = recipe.input_type_1
	producer.input1_needed = recipe.input_1_needed
	producer.input1_from_map = recipe.input_1_from_map
	producer.inputType2 = recipe.input_type_2
	producer.input2_needed = recipe.input_2_needed
	producer.outputType1 = recipe.output_type_1
	producer.output1_amount = recipe.output_1_amount
	producer.outputType2 = recipe.output_type_2
	producer.output2_amount = recipe.output_2_amount
	producer.max_speed = recipe.max_speed
	return producer


func get_work_types() -> Array[String]:
	if outputType1 != "" and outputType2 != "":
		return [outputType1, outputType2]
	elif outputType1 != "":
		return [outputType1]
	return []


func produce(train: Train, worker_modifier: float) -> int:
	var result = Globals.RESULT_OK
	chew_backlog(train)
	if progress == 0.0 and output1_backlog <= 0 and output2_backlog <= 0:
		if input_mode == ProductionRecipe.UsageMode.BOTH:
			result = start_cycle_both(train, worker_modifier)
		elif input_mode == ProductionRecipe.UsageMode.EITHER:
			result = start_cycle_either(train, worker_modifier)
		progress += carryOver
		carryOver = 0.0
	if progress > 0.0 and progress < 1.0:
		make_progress(train, worker_modifier)
	if progress >= 1.0:
		finish_cycle(train)

	return result


func start_cycle_both(train: Train, worker_modifier: float) -> int:
	var result = Globals.RESULT_OK

	if max_speed >= 0 and train.speed > max_speed:
		return Globals.EXCEEDS_MAX_SPEED

	if inputType1 != "":
		var input1_avail = train.get_res(inputType1)
		if input1_from_map == false:
			result = Helpers.exceeds_safety_margin(train, inputType1, outputType1, outputType2, input1_needed)
			if input1_avail < input1_needed:
				result = Globals.NO_RESOURCES
				if result == Globals.RESULT_OK and inputType2 != "":
					var input2_avail = train.get_res(inputType2)
					result = Helpers.exceeds_safety_margin(train, inputType2, outputType1, outputType2, input2_needed)
					if input2_avail < input2_needed:
						result = Globals.NO_RESOURCES
		elif input1_from_map == true:
			result = train.worldMap.gather_resource(inputType1, input1_needed)

	if result == Globals.RESULT_OK:
		if input1_from_map == false and inputType1 != "":
			train.add_res(inputType1, -1 * input1_needed)
			if inputType2 != "":
				train.add_res(inputType2, -1 * input2_needed)
		progress = progress + (worker_modifier / cycleTime)
	return result


func start_cycle_either(train: Train, worker_modifier: float) -> int:
	var result = Globals.RESULT_OK

	if max_speed >= 0 and train.speed > max_speed:
		return Globals.EXCEEDS_MAX_SPEED

	if inputType1 != "":
		var input1_avail = train.get_res(inputType1)
		if input1_from_map == false:
			result = Helpers.exceeds_safety_margin(train, inputType1, outputType1, outputType2, input1_needed)
			if input1_avail < input1_needed:
				result = Globals.NO_RESOURCES
		elif input1_from_map == true:
			result = train.worldMap.gather_resources(inputType1, input1_needed)

	if result == Globals.RESULT_OK:
		if input1_from_map == false and inputType1 != "":
			train.add_res(inputType1, -1 * input1_needed)
		progress = progress + (1.0 / cycleTime)
		return Globals.RESULT_OK

	if result != Globals.RESULT_OK:
		if inputType2 != "":
			result = Helpers.exceeds_safety_margin(train, inputType2, outputType1, outputType2, input2_needed)
			var input2_avail = train.get_res(inputType2)
			if input2_avail < input2_needed:
				result = Globals.NO_RESOURCES

	if result == Globals.RESULT_OK:
		if inputType2 != "":
			train.add_res(inputType2, -1 * input2_needed)
		progress = progress + (worker_modifier / cycleTime)

	return result


func chew_backlog(train: Train) -> void:
	if output1_backlog > 0:
		output1_backlog = train.add_res(outputType1, output1_backlog)
	if output2_backlog > 0:
		output2_backlog = train.add_res(outputType2, output2_backlog)


func make_progress(train: Train, worker_modifier: float) -> void:
	if max_speed >= 0 and train.speed > max_speed:
		return
	progress = progress + (worker_modifier / cycleTime)


func finish_cycle(train: Train) -> void:
	carryOver = max(0, progress - 1.0)
	progress = 0.0
	if outputType1 != "":
		if outputType1 == "pop":
			train.passengerManager.add_passenger()
			return
		output1_backlog += train.add_res(outputType1, output1_amount)
		if outputType2 != "":
			output2_backlog += train.add_res(outputType2, output2_amount)
