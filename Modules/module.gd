extends Node2D

class_name ModuleBase

var parentCar : TraincarBase = null
var parentTrain : Train = null
var type : String = "empty"
var sequence : int = 0

var enabled : bool = true

# Service variables
var services : Array[ServiceProvider] = []
var serves_needs : Array[String] = []
var customers : Array[Passenger] = []
var service_speed_modifier = 1.0


# Production Variables
var workers_needed : int = 0
var ticks_to_produce : int = 1    # How many ticks needed to finish production
var production_rate = 1.0
var progress : float = 0.0    # For modules that take more than one tick to produce a material
var workers : Array[Passenger] = []


# All modules should know their parents and set position
func _ready():
	parentCar = get_parent()
	parentTrain = parentCar.get_parent()
	position.x = sequence * Globals.module_width

func can_enter(myPassenger : Passenger) -> bool:
	return true

func worker_can_enter(newWorker : Passenger) -> bool:
	if enabled == false or workers.size() >= workers_needed:
		return false
	return true

func can_serve_need(testType : String) -> bool:
	if enabled == true and serves_needs.has(testType):
		return true
	return false

func needs_worker(work_type : String) -> bool:
	if enabled == true:
		if work_type == "any" and (workers_needed - workers.size()) > 0:
			return true
	return false

# For modules which produce or consume resources unrelated to presence of customers
func resource_tick():
	if enabled == false:
		return
	elif type == "empty":
		if customers.size() > 0:
			serve_customers()	# Will kick out customers as no needs to be fulfilled
		return
	
	# Producing materials requires workers
	if workers.size() >= workers_needed:
		if type == "farm":
			if (parentTrain.get_res("clean_water") > Globals.minimum_water_safety_margin):
				if parentTrain.get_res("grey_water") > 0:
					parentTrain.add_res("food1", 1)
					parentTrain.add_res("grey_water", -1)
				elif (parentTrain.get_res("clean_water") > 0): 
					parentTrain.add_res("food1", 1)
					parentTrain.add_res("clean_water", -1)
				

		if type == "scrap_arm":
			var scrap_gathered = parentTrain.worldMap.request_resources("scrap", production_rate)
			parentTrain.add_res("scrap", scrap_gathered)
		#commenting out code contributed by junior dev
		# 2qv c
		#re adding 5 lines of code removed by junior dev
		elif type == "clean_water":
			# Prioritise black water first
			if parentTrain.get_res("black_water") >= 1:
				parentTrain.add_res("black_water", -1)
				parentTrain.add_res("grey_water", 1)
			else:
				var grey_water = parentTrain.get_res("grey_water")
				var amount_to_convert = min(grey_water, 1)
				if amount_to_convert >= 1:
					parentTrain.add_res("grey_water", (-1 * amount_to_convert))
					parentTrain.add_res("clean_water", amount_to_convert)
		elif type == "mech_parts":
			# Production has not started yet:
			var scrap = parentTrain.get_res("scrap")
			# multi-tick production
			if ticks_to_produce > 0:
				if progress == 0.0:
					if scrap >= 5:
						parentTrain.add_res("scrap", -5)
						progress = progress + (1.0 / ticks_to_produce)
				else:
					progress = progress + (1.0 / ticks_to_produce)

				# Complete production
				if progress >= 1.0:
					var amount_to_produce = 5 * Globals.scrap_to_mech_ratio
					parentTrain.add_res("mech_parts", amount_to_produce)
					progress = 0.0

			else:
				if scrap >= 5:
					parentTrain.add_res("scrap", -5)
					var amount_to_produce = 5 * Globals.scrap_to_mech_ratio
					parentTrain.add_res("mech_parts", amount_to_produce)
	if serves_needs.size() > 0:
		serve_customers()

func set_sequence(newSequence : int):
	sequence = newSequence
	position.x = sequence * Globals.module_width

func add_customer(newCustomer : Passenger):
	if customers.has(newCustomer) == false:
		customers.append(newCustomer)
		$DebugCustomerCount.text = "" + String.num_int64(customers.size())
		for service in services:
			if service.trigger_once == true:
				service.serve_customer(newCustomer, parentTrain, self)

func remove_customer(currentCustomer : Passenger):
	customers.erase(currentCustomer)
	$DebugCustomerCount.text = "" + String.num_int64(customers.size())

func add_worker(newWorker : Passenger):
	if workers.has(newWorker) == false:
		workers.append(newWorker)
		$DebugWorkerCount.text = "" + String.num_int64(workers.size())

func remove_worker(newWorker : Passenger):
	workers.erase(newWorker)
	$DebugWorkerCount.text = "" + String.num_int64(workers.size())

func add_service(newProvider : ServiceProvider):
	newProvider.init()	# Setup its initial variables
	services.append(newProvider)
	serves_needs.append(newProvider.outputType)

## For each customer in the module, run through the repeatable services and attempt to provide them
func serve_customers():
	for customer in customers:
		if is_instance_valid(customer):
			var services_finished = 0
			for service in services:
				if service.trigger_once == false:
					var result = service.serve_customer(customer, parentTrain, self)
					if result == Globals.SERVICE_FINISHED or result == Globals.NO_RESOURCES:
						services_finished += 1
				else:
					services_finished += 1 # Trigger-once services shouldn't count against total
			
			if services_finished >= services.size():
				remove_customer(customer)
				print("%s %s exiting %s module" % [customer.firstname, customer.lastname, type]) 
				customer.exit_customer_module()

func reset_module():
	services = []
	serves_needs = []
	workers_needed = 0
	progress = 0.0
	ticks_to_produce = 1
	$Outline.color = Color.GRAY

func set_type(newType : String):
	self.type = newType
	reset_module()                    # Start from state of an 'empty' module
	if newType == "clean_water":
		$Outline.color = Color.AQUA
		var basicWaterProvider = BasicWaterProvider.new()
		add_service(basicWaterProvider)
		workers_needed = 1
	elif newType == "cabin":
		$Outline.color = Color.BROWN
		var showerProvider = ShowerProvider.new()
		var basicBedProvider = BasicBedProvider.new()
		add_service(showerProvider)
		add_service(basicBedProvider)
	elif newType == "kitchen":
		$Outline.color = Color.BISQUE
		var basicFoodProvider = BasicFoodProvider.new()
		var basicWaterProvider = BasicWaterProvider.new()
		add_service(basicFoodProvider)
		add_service(basicWaterProvider)
	elif newType == "farm":
		$Outline.color = Color.SEA_GREEN
		var basicFoodProvider = BasicFoodProvider.new()
		add_service(basicFoodProvider)
		workers_needed = 1
	elif newType == "scrap_arm":
		$Outline.color = Color.SANDY_BROWN
		production_rate = 5.0
	elif newType == "mech_parts":
		$Outline.color = Color.SANDY_BROWN
		workers_needed = 1
		ticks_to_produce = 2
	$Label.text = newType
