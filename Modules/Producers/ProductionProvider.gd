extends RefCounted

class_name ProductionProvider

var cycleTime: int = 1
var progress: float = 0.0
var carryOver: float = 0.0

var output_type_1: ResourceType = null
var output1_amount: float = 0.0
var output1_backlog: float = 0.0

var output_type_2: ResourceType = null
var output2_amount: float = 0.0
var output2_backlog: float = 0.0

var input_mode: ProductionRecipe.UsageMode = ProductionRecipe.UsageMode.BOTH

var input_type_1: ResourceType = null
var input1_needed: float = 0.0
var input1_from_map: bool = false
var max_speed: float = -1.0

var input_type_2: ResourceType = null
var input2_needed: float = 0.0


static func from_recipe(recipe: ProductionRecipe) -> ProductionProvider:
	var producer := ProductionProvider.new()
	producer.cycleTime = recipe.cycle_time
	producer.input_mode = recipe.input_mode
	producer.input_type_1 = recipe.input_type_1
	producer.input1_needed = recipe.input_1_needed
	producer.input1_from_map = recipe.input_1_from_map
	producer.input_type_2 = recipe.input_type_2
	producer.input2_needed = recipe.input_2_needed
	producer.output_type_1 = recipe.output_type_1
	producer.output1_amount = recipe.output_1_amount
	producer.output_type_2 = recipe.output_type_2
	producer.output2_amount = recipe.output_2_amount
	producer.max_speed = recipe.max_speed
	return producer


func get_work_types() -> Array[String]:
	var work_types: Array[String] = []
	work_types.append("any")
	_append_work_category(work_types, output_type_1)
	_append_work_category(work_types, output_type_2)
	return work_types


func _append_work_category(work_types: Array[String], resource_type: ResourceType) -> void:
	if resource_type == null:
		return
	var category := resource_type.category
	if category != "" and not work_types.has(category):
		work_types.append(category)


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

	if input_type_1 != null:
		var input1_name := input_type_1.type_name
		var output1_name := _type_name(output_type_1)
		var output2_name := _type_name(output_type_2)
		var input1_avail = train.get_res(input1_name)
		if input1_from_map == false:
			result = Helpers.exceeds_safety_margin(train, input1_name, output1_name, output2_name, input1_needed)
			if input1_avail < input1_needed:
				result = Globals.NO_RESOURCES
				if result == Globals.RESULT_OK and input_type_2 != null:
					var input2_name := input_type_2.type_name
					var input2_avail = train.get_res(input2_name)
					result = Helpers.exceeds_safety_margin(train, input2_name, output1_name, output2_name, input2_needed)
					if input2_avail < input2_needed:
						result = Globals.NO_RESOURCES
		elif input1_from_map == true:
			result = train.worldMap.gather_resource(input1_name, input1_needed)

	if result == Globals.RESULT_OK:
		if input1_from_map == false and input_type_1 != null:
			train.add_res(input_type_1.type_name, -1 * input1_needed)
			if input_type_2 != null:
				train.add_res(input_type_2.type_name, -1 * input2_needed)
		progress = progress + (worker_modifier / cycleTime)
	return result


func start_cycle_either(train: Train, worker_modifier: float) -> int:
	var result = Globals.RESULT_OK

	if max_speed >= 0 and train.speed > max_speed:
		return Globals.EXCEEDS_MAX_SPEED

	if input_type_1 != null:
		var input1_name := input_type_1.type_name
		var output1_name := _type_name(output_type_1)
		var output2_name := _type_name(output_type_2)
		var input1_avail = train.get_res(input1_name)
		if input1_from_map == false:
			result = Helpers.exceeds_safety_margin(train, input1_name, output1_name, output2_name, input1_needed)
			if input1_avail < input1_needed:
				result = Globals.NO_RESOURCES
		elif input1_from_map == true:
			result = train.worldMap.gather_resources(input1_name, input1_needed)

	if result == Globals.RESULT_OK:
		if input1_from_map == false and input_type_1 != null:
			train.add_res(input_type_1.type_name, -1 * input1_needed)
		progress = progress + (1.0 / cycleTime)
		return Globals.RESULT_OK

	if result != Globals.RESULT_OK:
		if input_type_2 != null:
			var input2_name := input_type_2.type_name
			var output1_name := _type_name(output_type_1)
			var output2_name := _type_name(output_type_2)
			result = Helpers.exceeds_safety_margin(train, input2_name, output1_name, output2_name, input2_needed)
			var input2_avail = train.get_res(input2_name)
			if input2_avail < input2_needed:
				result = Globals.NO_RESOURCES

	if result == Globals.RESULT_OK:
		if input_type_2 != null:
			train.add_res(input_type_2.type_name, -1 * input2_needed)
		progress = progress + (worker_modifier / cycleTime)

	return result


func chew_backlog(train: Train) -> void:
	if output1_backlog > 0 and output_type_1 != null:
		output1_backlog = train.add_res(output_type_1.type_name, output1_backlog)
	if output2_backlog > 0 and output_type_2 != null:
		output2_backlog = train.add_res(output_type_2.type_name, output2_backlog)


func make_progress(train: Train, worker_modifier: float) -> void:
	if max_speed >= 0 and train.speed > max_speed:
		return
	progress = progress + (worker_modifier / cycleTime)


func finish_cycle(train: Train) -> void:
	carryOver = max(0, progress - 1.0)
	progress = 0.0
	if output_type_1 != null:
		if output_type_1.type_name == "pop":
			train.passengerManager.add_passenger()
			return
		output1_backlog += train.add_res(output_type_1.type_name, output1_amount)
		if output_type_2 != null:
			output2_backlog += train.add_res(output_type_2.type_name, output2_amount)


static func _type_name(resource_type: ResourceType) -> String:
	if resource_type == null:
		return ""
	return resource_type.type_name
