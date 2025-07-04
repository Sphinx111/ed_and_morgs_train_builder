extends Node2D

class_name ModuleBase

var parentCar : TraincarBase = null
var parentTrain : Train = null
var type : String = "empty"
var serves_needs : Array[String] = []
var service_rate : float = 0.1
var sequence : int = 0
#var efficiency : float = 1.0
var workers_needed : int = 0

var workers : Array[Passenger] = []
var customers : Array[Passenger] = []

var enabled : bool = true

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
		return
	
	if workers.size() >= workers_needed:
		if type == "farm":
			if (parentTrain.get_res("clean_water") > Globals.minimum_water_safety_margin):
				if parentTrain.get_res("grey_water") > 0:
					parentTrain.add_res("food1", 1)
					parentTrain.add_res("grey_water", -1)
				elif (parentTrain.get_res("clean_water") > 0): 
					parentTrain.add_res("food1", 1)
					parentTrain.add_res("clean_water", -1)
				
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
	serve_customers()

func set_sequence(newSequence : int):
	sequence = newSequence
	position.x = sequence * Globals.module_width

func add_customer(newCustomer : Passenger):
	if customers.has(newCustomer) == false:
		customers.append(newCustomer)
		$DebugCustomerCount.text = "" + String.num_int64(customers.size())

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

func serve_customers():
	if customers.size() == 0:
		return
	for customer in customers:
		# For each need served here, check how much the customer wants
		# Then consume resources to fulfill the need
		
		# track how many needs have been satisfied out of total available, so customer will leave when needs are met
		var needs_finished : int = 0
		for need in serves_needs:
			var amount : float = min(customer.needs[need], service_rate)
			if amount == 0:
				needs_finished += 1
			elif amount > 0:
				var resource_to_use : String = ""
				var resource_to_produce : String = ""
				if need == "thirst":
					resource_to_use = "clean_water"
					resource_to_produce = "black_water"
				if need == "hunger":
					resource_to_use = "food1"
					resource_to_produce = "black_water"
				if need == "rest":
					resource_to_use = "clean_water"
					resource_to_produce = "grey_water"
				
				if resource_to_use != "none":
					amount = min(parentTrain.res[resource_to_use], amount)      # Reduce amount if train has less than desired
					parentTrain.res[resource_to_use] -= amount
					parentTrain.res[resource_to_produce] += amount

				if customer.adjust_need(need, amount) == 0:                     # Actually adjust the passenger's need, and get amount remaining
					needs_finished += 1
		
		if needs_finished >= serves_needs.size():
			remove_customer(customer)
			print("%s %s exiting %s module" % [customer.firstname, customer.lastname, type]) 
			customer.exit_customer_module()
		pass

func set_type(newType : String):
	self.type = newType
	if newType == "clean_water":
		$Outline.color = Color.AQUA
		serves_needs = ["thirst"]
		workers_needed = 1
	elif newType == "cabin":
		$Outline.color = Color.BROWN
		serves_needs = ["rest"]
	elif newType == "kitchen":
		$Outline.color = Color.BISQUE
		serves_needs = ["hunger", "thirst"]
	elif newType == "farm":
		$Outline.color = Color.SEA_GREEN
		serves_needs = ["hunger"]
		workers_needed = 1
	elif newType == "empty":
		$Outline.color = Color.GRAY
		serves_needs = []
	$Label.text = newType
