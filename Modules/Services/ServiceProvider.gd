extends RefCounted

class_name ServiceProvider

var trigger_once: bool = false
var output_need: String = ""
var output_rate: float = 0.0

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

	var percent_to_fulfill := 1.0

	if input_type_1 != null:
		percent_to_fulfill = _calc_input1_success(train, amount_wanted)
		if input_type_2 != null:
			var input2_percent := _calc_input2_success(train, amount_wanted)
			if input2_percent < percent_to_fulfill:
				percent_to_fulfill = input2_percent

	if percent_to_fulfill == 0.0:
		return Globals.NO_RESOURCES

	var water_content_added : float = _spend_resources(train, percent_to_fulfill, amount_wanted)
	customer.adjust_water_content(water_content_added)
	if waste_type_1 != null && waste_type_1.type_name == "black_water":
		_output_water_waste(train, customer)
	else:
		_output_waste(train, percent_to_fulfill, amount_wanted)
	var remaining_need := customer.adjust_need(output_need, amount_wanted * percent_to_fulfill)

	if remaining_need == 0.0:
		return Globals.SERVICE_FINISHED
	return Globals.RESULT_OK


func _calc_input1_success(train: Train, amount_wanted: float) -> float:
	var res_available := train.get_res(input_type_1.type_name)
	var res_wanted := amount_wanted * input1_needed
	return min(res_available / res_wanted, 1.0)


func _calc_input2_success(train: Train, amount_wanted: float) -> float:
	var res_available := train.get_res(input_type_2.type_name)
	var res_wanted := amount_wanted * input2_needed
	return min(res_available / res_wanted, 1.0)


func _spend_resources(train: Train, percent_to_spend: float, amount_served: float) -> float:
	if input_type_1 != null:
		var amount_to_spend : float = input1_needed * percent_to_spend * amount_served 
		train.add_res(input_type_1.type_name, -1 * amount_to_spend)
		return amount_to_spend * input_type_1.water_content
	elif input_type_2 != null:
		var amount_to_spend : float = input2_needed * percent_to_spend * amount_served 
		train.add_res(input_type_2.type_name, -1 * input2_needed * percent_to_spend * amount_served)
		return amount_to_spend * input_type_2.water_content
	return 0.0


func _output_waste(train: Train, percent_to_produce: float, amount_served: float) -> void:
	if waste_type_1 != null:
		train.add_res(waste_type_1.type_name, waste1_produced * percent_to_produce * amount_served)

func _output_water_waste(train : Train, customer : Passenger) -> void:
	if waste_type_1.type_name != "black_water":
		push_error("_output_water_waste used by wrong module type")
	if customer.water_content > 0.0:
		train.add_res(waste_type_1.type_name, customer.water_content)
		customer.adjust_water_content(-1 * customer.water_content)
