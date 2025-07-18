extends Node2D

class_name ModuleBase

var parentCar : TraincarBase = null
var parentTrain : Train = null
var type : String = "empty"
var sequence : int = 0

var enabled : bool = true

const build_cost : Dictionary[String, float] = {
	"clean_water" : 25.0,
	"mech_parts" : 20.0,
	"farm" : 10.0,
	"scrap_arm" : 10.0,
	"kitchen" : 5.0,
	"cabin" : 2.0,
	"passenger_door" : 5.0,
	"water_collector" : 25.0
}

# Service variables
var services : Array[ServiceProvider] = []
var serves_needs : Array[String] = []
var customers : Array[Passenger] = []
var service_speed_modifier = 1.0
var maxCustomers : int = 0

# Production Variables
var producers : Array[ProductionProvider] = [] 
var workers_needed : int = 0
var workers : Array[Passenger] = []
var work_types : Array[String] = ["any"]

# Storage Variables
var storages : Array[GenericStorageProvider] = []

# All modules should know their parents and set position
func _ready():
	parentCar = get_parent()
	parentTrain = parentCar.get_parent()
	if Globals.train_direction < 0:
		position.x = sequence * Globals.module_width
	else:
		position.x = Globals.car_length - ((sequence + 1) * Globals.module_width)

func can_enter(myPassenger : Passenger) -> bool:
	if maxCustomers == 0 or customers.size() < maxCustomers:
		return true
	return false

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
		if work_type in work_types and (workers_needed - workers.size()) > 0:
			return true
	return false

# For modules which produce or consume resources unrelated to presence of customers
func resource_tick():
	if enabled == false:
		return
	elif type == "empty":
		return
	
	if services.size() > 0:
		serve_customers()
	
	if producers.size() > 0:
		produce_resources()
		return

func set_sequence(newSequence : int):
	sequence = newSequence
	if Globals.train_direction < 0:
		position.x = sequence * Globals.module_width
	else:
		position.x = Globals.car_length - ((sequence + 1) * Globals.module_width)

func add_customer(newCustomer : Passenger):
	if customers.has(newCustomer) == false:
		customers.append(newCustomer)
		$DebugCustomerCount.text = "" + String.num_int64(customers.size())
		if customers.size() == maxCustomers:
			parentCar.update_needs_maps(serves_needs, sequence, Globals.CUSTOMERS_FULL)
		for service in services:
			if service.trigger_once == true:
				service.serve_customer(newCustomer, parentTrain, self)

## Used by module to remove its own passengers
func _eject_customer(currentCustomer : Passenger):
	notify_remove_customer(currentCustomer)
	currentCustomer.exit_customer_module()

## Used by external classes telling module to remove
func notify_remove_customer(currentCustomer : Passenger):
	if customers.size() == maxCustomers:
		parentCar.update_needs_maps(serves_needs, sequence, Globals.CUSTOMERS_HAS_SPACE)
	customers.erase(currentCustomer)
	$DebugCustomerCount.text = "" + String.num_int64(customers.size())

func add_worker(newWorker : Passenger):
	if workers.has(newWorker) == false:
		workers.append(newWorker)
		$DebugWorkerCount.text = "" + String.num_int64(workers.size())
		if workers.size() == workers_needed:
			for workType in work_types:
				parentTrain.update_work_map(workType)

func remove_worker(newWorker : Passenger):
	if workers.size() == workers_needed:
		for workType in work_types:
			parentTrain.update_work_map(workType)
	workers.erase(newWorker)
	$DebugWorkerCount.text = "" + String.num_int64(workers.size())

func _eject_worker(oldWorker : Passenger):
	oldWorker.worker_ejected_from_module()

func add_service(newProvider : ServiceProvider):
	newProvider.init()	# Setup its initial variables
	services.append(newProvider)
	serves_needs.append(newProvider.outputType)
	work_types.append_array(newProvider.get_work_types())

func add_producer(newProducer : ProductionProvider):
	newProducer.init()	# Setup initial variables
	producers.append(newProducer)
	work_types.append_array(newProducer.get_work_types())

func add_custom_storage(storageDict : Dictionary):
	var newStorage = GenericStorageProvider.new()
	for key in storageDict:
		newStorage.add_storage(key, storageDict[key])
	storages.append(newStorage)
	newStorage.create_storage(parentTrain)
	

## Cycle through producers and run their production cycle
func produce_resources():
	# Producing materials requires workers
	if workers.size() >= workers_needed:
		for producer in producers:
			var worker_modifier = 1.0
			if workers_needed > 0:
				worker_modifier = workers.size() / float(workers_needed)
			producer.produce(parentTrain, worker_modifier)

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
				_eject_customer(customer)
				#print("%s %s exiting %s module" % [customer.firstname, customer.lastname, type])
		else:
			customers.erase(customer)

func reset_module():
	services = []
	producers = []
	serves_needs = []
	work_types = ["any"]
	workers_needed = 0
	$Outline.color = Color.GRAY
	
	# Kick out any customers when module type changes
	for customer in customers:
		if is_instance_valid(customer):
			_eject_customer(customer)
			_eject_worker(customer)
	workers = []
	customers = []
	
	# Remove any storage provision from train
	for storage in storages:
		storage.remove_storage(parentTrain)

func set_type(newType : String):
	reset_module()                    # Start from state of an 'empty' module
	self.type = newType
	if newType == "empty":
		return
	if newType == "clean_water":
		$Outline.color = Color.AQUA
		var basicWaterProvider = BasicWaterProvider.new()
		add_service(basicWaterProvider)
		maxCustomers = 4
		
		# Setup production
		var basicCleanWaterProducer = BasicCleanWaterProducer.new()
		add_producer(basicCleanWaterProducer)
		workers_needed = 1

		# Setup storagge
		add_custom_storage({"clean_water" : 25.0,"grey_water" : 25.0, "black_water" : 10.0})
	elif newType == "cabin":
		$Outline.color = Color.BROWN
		var showerProvider = ShowerProvider.new()
		var basicBedProvider = BasicBedProvider.new()
		add_service(showerProvider)
		add_service(basicBedProvider)
		maxCustomers = 4
	elif newType == "kitchen":
		$Outline.color = Color.BISQUE
		var basicFoodProvider = BasicFoodProvider.new()
		var basicWaterProvider = BasicWaterProvider.new()
		add_service(basicFoodProvider)
		add_service(basicWaterProvider)
		add_custom_storage({"clean_water" : 20.0,"food1" : 10.0,"food2" : 10.0})
		maxCustomers = 10
	elif newType == "farm":
		$Outline.color = Color.SEA_GREEN
		var basicFoodProvider = BasicFoodProvider.new()
		add_service(basicFoodProvider)
		maxCustomers = 5
		
		# Setup production
		var food1Producer = BasicFood1Producer.new()
		add_producer(food1Producer)
		workers_needed = 5
		
		# Setup storage
		add_custom_storage({"food1" : 50.0})
	elif newType == "scrap_arm":
		$Outline.color = Color.SANDY_BROWN
		var scrapCollector = BasicScrapCollector.new()
		add_producer(scrapCollector)#
		workers_needed = 1
		add_custom_storage({"scrap" : 50.0})
	elif newType == "mech_parts":
		$Outline.color = Color.SANDY_BROWN
		var partsProducer = ScrapToMechProducer.new()
		add_producer(partsProducer)
		workers_needed = 1
		add_custom_storage({"mech_parts" : 50.0})
	elif newType == "passenger_door":
		$Outline.color = Color.CORNFLOWER_BLUE
		var passengerCollector = BasicPassengerCollector.new()
		add_producer(passengerCollector)
	elif newType == "water_collector":
		$Outline.color = Color.CADET_BLUE
		var waterCollector = BasicWaterCollector.new()
		add_producer(waterCollector)
		workers_needed = 1
		add_custom_storage({"grey_water" : 100.0})
	$Label.text = newType
	for workType in work_types:
		parentTrain.update_work_map(workType)
