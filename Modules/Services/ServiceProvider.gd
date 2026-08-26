extends RefCounted

class_name ServiceProvider

var trigger_once: bool = false
var output_need: String = ""
var output_rate: float = 0.0

var input_mode: ServiceRecipe.InputMode = ServiceRecipe.InputMode.USE_BOTH

var input_type_1: ResourceType = null
var input1_needed: float = 0.0

var input_type_2: ResourceType = null
var input2_needed: float = 0.0

var waste_type_1: ResourceType = null
var waste1_produced: float = 0.0


static func from_recipe(recipe: ServiceRecipe) -> ServiceProvider:
	var provider := ServiceProvider.new()
	provider.trigger_once = recipe.trigger_once
	provider.output_need = recipe.output_need
	provider.output_rate = recipe.output_rate
	provider.input_mode = recipe.input_mode
	provider.input_type_1 = recipe.input_type_1
	provider.input1_needed = recipe.input_1_needed
	provider.input_type_2 = recipe.input_type_2
	provider.input2_needed = recipe.input_2_needed
	provider.waste_type_1 = recipe.waste_type_1
	provider.waste1_produced = recipe.waste_1_produced
	return provider


func get_work_types() -> Array[String]:
	var work_types: Array[String] = []
	_append_work_category(work_types, input_type_1)
	_append_work_category(work_types, input_type_2)
	return work_types


func _append_work_category(work_types: Array[String], resource_type: ResourceType) -> void:
	if resource_type == null:
		return
	var category := resource_type.category
	if category == "":
		category = resource_type.type_name
	if category != "" and not work_types.has(category):
		work_types.append(category)


func serve_customer(customer: Passenger, train: Train, module: ModuleBase) -> int:
	var amount_wanted := 1.0

	if output_need != "":
		amount_wanted = customer.wants_need(output_need)
		if amount_wanted == 0.0:
			return Globals.SERVICE_FINISHED

		amount_wanted = min(amount_wanted, output_rate)
		amount_wanted = amount_wanted * module.service_speed_modifier

	var input_plan := _resolve_input_plan(train, amount_wanted)
	if input_plan.percent == 0.0 and not input_plan.inputs.is_empty():
		return Globals.NO_RESOURCES

	var water_content_added: float = _spend_resources(train, input_plan, amount_wanted)
	customer.adjust_water_content(water_content_added)
	if waste_type_1 != null && waste_type_1.type_name == "black_water":
		_output_water_waste(train, customer)
	else:
		_output_waste(train, input_plan.percent, amount_wanted)
	var remaining_need := customer.adjust_need(output_need, amount_wanted * input_plan.percent)

	if remaining_need == 0.0:
		return Globals.SERVICE_FINISHED
	return Globals.RESULT_OK


func _resolve_input_plan(train: Train, amount_wanted: float) -> Dictionary:
	var plan := {
		"percent": 1.0,
		"inputs": [],
	}

	if input_mode == ServiceRecipe.InputMode.USE_BOTH:
		return _resolve_both_input_plan(train, amount_wanted, plan)
	if input_mode == ServiceRecipe.InputMode.USE_EITHER:
		return _resolve_either_input_plan(train, amount_wanted, plan)

	if input_type_1 != null and input1_needed > 0.0:
		plan.percent = _calc_input_success(train, input_type_1, input1_needed, amount_wanted)
		plan.inputs.append({"type": input_type_1, "needed": input1_needed})
	return plan


func _resolve_both_input_plan(train: Train, amount_wanted: float, plan: Dictionary) -> Dictionary:
	var percent := 1.0
	var has_input := false

	if input_type_1 != null and input1_needed > 0.0:
		has_input = true
		percent = _calc_input_success(train, input_type_1, input1_needed, amount_wanted)
		plan.inputs.append({"type": input_type_1, "needed": input1_needed})

	if input_type_2 != null and input2_needed > 0.0:
		has_input = true
		var input2_percent := _calc_input_success(train, input_type_2, input2_needed, amount_wanted)
		percent = min(percent, input2_percent)
		plan.inputs.append({"type": input_type_2, "needed": input2_needed})

	if not has_input:
		plan.percent = 1.0
	else:
		plan.percent = percent
	return plan


func _resolve_either_input_plan(train: Train, amount_wanted: float, plan: Dictionary) -> Dictionary:
	if input_type_1 != null and input1_needed > 0.0:
		var input1_percent := _calc_input_success(train, input_type_1, input1_needed, amount_wanted)
		if input1_percent > 0.0:
			plan.percent = input1_percent
			plan.inputs.append({"type": input_type_1, "needed": input1_needed})
			return plan

	if input_type_2 != null and input2_needed > 0.0:
		var input2_percent := _calc_input_success(train, input_type_2, input2_needed, amount_wanted)
		if input2_percent > 0.0:
			plan.percent = input2_percent
			plan.inputs.append({"type": input_type_2, "needed": input2_needed})
			return plan

	plan.percent = 0.0
	return plan


func _calc_input_success(train: Train, resource_type: ResourceType, input_needed: float, amount_wanted: float) -> float:
	var res_available := train.get_res(resource_type.type_name)
	var res_wanted := amount_wanted * input_needed
	if res_wanted <= 0.0:
		return 1.0
	return min(res_available / res_wanted, 1.0)


func _spend_resources(train: Train, input_plan: Dictionary, amount_served: float) -> float:
	var water_content_added := 0.0
	for input_entry in input_plan.inputs:
		var resource_type: ResourceType = input_entry.type
		var input_needed: float = input_entry.needed
		var amount_to_spend : float = input_needed * input_plan.percent * amount_served
		train.add_res(resource_type.type_name, -1 * amount_to_spend)
		water_content_added += amount_to_spend * resource_type.water_content
	return water_content_added


func _output_waste(train: Train, percent_to_produce: float, amount_served: float) -> void:
	if waste_type_1 != null:
		train.add_res(waste_type_1.type_name, waste1_produced * percent_to_produce * amount_served)


func _output_water_waste(train: Train, customer: Passenger) -> void:
	if waste_type_1.type_name != "black_water":
		push_error("_output_water_waste used by wrong module type")
	if customer.water_content > 0.0:
		train.add_res(waste_type_1.type_name, customer.water_content)
		customer.adjust_water_content(-1 * customer.water_content)
