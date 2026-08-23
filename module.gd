extends Node2D

class_name ModuleBase

var parentCar : TraincarBase = null
var parentTrain : Train = null
var type : String = "empty"
var sequence : int = 0
var mass : float = 250.0
var adjacencies : int = 0

var enabled : bool = true

const build_cost : Dictionary[String, float] = {
	"clean_water" : 25.0,
	"mech_parts" : 20.0,
	"farm" : 10.0,
	"scrap_arm" : 10.0,
	"kitchen" : 5.0,
	"cabin" : 2.0,
	"passenger_door" : 5.0,
	"water_collector" : 25.0,
	"fuel_refinery" : 50.0
}

# Service variables
var services : Array[ServiceProvider] = []
var serves_needs : Array[String] = []
var customers : Array[Passenger] = []
var service_speed_modifier = 1.0
var baseCustomers : int = 0
var maxCustomers : int = 0
var customers_per_adjacency : int = floor(maxCustomers / (1 / Globals.ADJACENCY_BONUS))

# Production Variables
var producers : Array[ProductionProvider] = [] 
var workers_needed : int = 0
var workers : Array[Passenger] = []
var work_types : Array[String] = []

# Storage Variables
var storages : Array[GenericStorageProvider] = []

const PRODUCTION_PROGRESS_HEIGHT : float = 50.0
const PRODUCTION_PROGRESS_BOTTOM : float = 80.0
const INSPECTOR_SCENE : PackedScene = preload("res://module_inspector.tscn")

var _click_area : Area2D = null
var _inspector : ModuleInspector = null

# All modules should know their parents and set position
func _ready():
	parentCar = get_parent()
	parentTrain = parentCar.get_parent()
	if Globals.train_direction < 0:
		position.x = sequence * Globals.module_width
	else:
		position.x = Globals.car_length - ((sequence + 1) * Globals.module_width)
	_setup_click_area()

func can_enter(_myPassenger : Passenger) -> bool:
	if maxCustomers == 0 or customers.size() < maxCustomers:
		return true
	return false

func worker_can_enter(_newWorker : Passenger) -> bool:
	if enabled == false or workers.size() >= workers_needed:
		return false
	return true

func can_serve_need(testType : String) -> bool:
	if enabled == true and serves_needs.has(testType):
		return true
	return false

func needs_worker(work_type : String) -> bool:
	if enabled == true:
		if work_types.has(work_type) and (workers_needed - workers.size()) > 0:
			return true
	return false

# For modules which produce or consume resources unrelated to presence of customers
func resource_tick():
	if type == "empty":
		return
	$Label.text = "%s %d" % [type, adjacencies]
	if enabled == false:
		return
	
	if services.size() > 0:
		serve_customers()
	
	if producers.size() > 0:
		produce_resources()
	else:
		_update_production_progress(0.0)
		return
	
	if _inspector != null and is_instance_valid(_inspector):
		_inspector.tick()

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
func _eject_customer(currentCustomer : Passenger) -> void:
	if not is_instance_valid(currentCustomer):
		return
	notify_remove_customer(currentCustomer)
	currentCustomer.ejected_from_module()

## Used by external classes telling module to remove
func notify_remove_customer(currentCustomer : Passenger) -> void:
	if not is_instance_valid(currentCustomer):
		return
	if not customers.has(currentCustomer):
		return
	if customers.size() == maxCustomers:
		parentCar.update_needs_maps(serves_needs, sequence, Globals.CUSTOMERS_HAS_SPACE)
	customers.erase(currentCustomer)
	$DebugCustomerCount.text = "" + String.num_int64(customers.size())

func add_worker(newWorker : Passenger):
	if workers.has(newWorker) == false:
		workers.append(newWorker)
		$DebugWorkerCount.text = "" + String.num_int64(workers.size())
		if workers.size() == workers_needed:
			parentCar.update_work_maps(work_types, sequence, Globals.WORKERS_FULL)

func notify_remove_worker(oldWorker : Passenger):
	if workers.size() == workers_needed:
		parentCar.update_work_maps(work_types, sequence, Globals.WORKERS_HAS_SPACE)
	workers.erase(oldWorker)
	$DebugWorkerCount.text = "" + String.num_int64(workers.size())

func _eject_worker(oldWorker : Passenger):
	oldWorker.worker_ejected_from_module()

func add_service_from_recipe(recipe: ServiceRecipe) -> void:
	var provider := ServiceProvider.from_recipe(recipe)
	services.append(provider)
	serves_needs.append(provider.output_need)
	for new_type in provider.get_work_types():
		if not work_types.has(new_type):
			work_types.append(new_type)


func add_services_for_type(module_type: String) -> void:
	for recipe in ServiceProviderRegistry.get_recipes_for_module(module_type):
		add_service_from_recipe(recipe)

func add_producer_from_recipe(recipe: ProductionRecipe) -> void:
	var producer := ProductionProvider.from_recipe(recipe)
	producers.append(producer)
	for new_type in producer.get_work_types():
		if not work_types.has(new_type):
			work_types.append(new_type)


func add_producers_for_type(module_type: String) -> void:
	for recipe in ModuleProducerRegistry.get_recipes_for_module(module_type):
		add_producer_from_recipe(recipe)

func add_custom_storage(storageDict : Dictionary):
	var newStorage = GenericStorageProvider.new()
	for key in storageDict:
		newStorage.add_storage(key, storageDict[key])
	storages.append(newStorage)
	newStorage.create_storage(parentTrain)
	

## Cycle through producers and run their production cycle
func produce_resources():
	_remove_invalid_workers()
	# Producing materials requires workers
	if workers_needed == 0 or workers.size() > 0:
		for producer in producers:
			var worker_modifier = 1.0
			if workers_needed > 0:
				worker_modifier = float(workers.size()) / float(workers_needed)
			worker_modifier += (adjacencies * Globals.ADJACENCY_BONUS)
			producer.produce(parentTrain, worker_modifier)
			_update_production_progress(producer.progress)
	else:
		_update_production_progress(0.0)


func _update_production_progress(progress : float) -> void:
	var bar_height : float = PRODUCTION_PROGRESS_HEIGHT * progress
	$DebugProgress.offset_top = PRODUCTION_PROGRESS_BOTTOM - bar_height
	$DebugProgress.offset_bottom = PRODUCTION_PROGRESS_BOTTOM
	$DebugProgress.visible = progress > 0.0

## For each customer in the module, run through the repeatable services and attempt to provide them
func serve_customers() -> void:
	_remove_invalid_customers()
	for i in range(customers.size() - 1, -1, -1):
		var customer: Passenger = customers[i]
		var services_finished := 0
		for service in services:
			if service.trigger_once == false:
				var result := service.serve_customer(customer, parentTrain, self)
				if result == Globals.SERVICE_FINISHED or result == Globals.NO_RESOURCES:
					services_finished += 1
			else:
				services_finished += 1

		if services_finished >= services.size():
			_eject_customer(customer)


func _remove_invalid_customers() -> void:
	for i in range(customers.size() - 1, -1, -1):
		if not is_instance_valid(customers[i]):
			customers.remove_at(i)
			$DebugCustomerCount.text = "" + String.num_int64(customers.size())

func _remove_invalid_workers() -> void:
	for i in range(workers.size() - 1, -1, -1):
		if not is_instance_valid(workers[i]):
			workers.remove_at(i)
			$DebugWorkerCount.text = "" + String.num_int64(workers.size())

func reset_module():
	hide_module_inspector()
	services = []
	producers = []
	serves_needs = []
	work_types = ["any"]
	workers_needed = 0
	$Outline.color = Color.GRAY
	
	# Kick out any customers and workers when module type changes
	for customer in customers:
		if is_instance_valid(customer):
			_eject_customer(customer)
	for worker in workers:
		if is_instance_valid(worker):
			_eject_worker(worker)
	workers = []
	customers = []
	_update_production_progress(0.0)
	
	# Remove any storage provision from train
	for storage in storages:
		storage.remove_storage(parentTrain)

func set_adjacency(newVal : int) -> void:
	adjacencies = newVal
	if (maxCustomers > 0):
		maxCustomers = baseCustomers + floor(baseCustomers * newVal * Globals.ADJACENCY_BONUS)

func set_type(newType : String):
	reset_module()                    # Start from state of an 'empty' module
	self.type = newType
	if newType == "empty":
		_update_click_area_enabled()
		return
	if newType == "clean_water":
		$Outline.color = Color.AQUA
		add_producers_for_type(newType)
		workers_needed = 1
		add_custom_storage({"clean_water" : 50.0,"grey_water" : 50.0, "black_water" : 10.0})
	elif newType == "cabin":
		$Outline.color = Color.BROWN
		add_services_for_type(newType)
		baseCustomers = 4
	elif newType == "kitchen":
		$Outline.color = Color.BISQUE
		add_services_for_type(newType)
		add_custom_storage({"clean_water" : 20.0,"food1" : 10.0,"food2" : 10.0})
		baseCustomers = 3
	elif newType == "farm":
		$Outline.color = Color.SEA_GREEN
		add_services_for_type(newType)
		baseCustomers = 5
		add_producers_for_type(newType)
		workers_needed = 5
		add_custom_storage({"food1" : 50.0})
	elif newType == "scrap_arm":
		$Outline.color = Color.SANDY_BROWN
		add_producers_for_type(newType)
		workers_needed = 1
		add_custom_storage({"scrap" : 50.0})
	elif newType == "mech_parts":
		$Outline.color = Color.SANDY_BROWN
		add_producers_for_type(newType)
		workers_needed = 1
		add_custom_storage({"mech_parts" : 50.0})
	elif newType == "passenger_door":
		$Outline.color = Color.CORNFLOWER_BLUE
		add_producers_for_type(newType)
	elif newType == "water_collector":
		$Outline.color = Color.CADET_BLUE
		add_producers_for_type(newType)
		workers_needed = 1
		add_custom_storage({"grey_water" : 100.0})
	elif newType == "fuel_refinery":
		$Outline.color = Color.DARK_SLATE_GRAY
		workers_needed = 8
		add_producers_for_type(newType)
		add_custom_storage({"oil" : 100.0, "fuel" : 100.0})
	$Label.text = newType
	maxCustomers = baseCustomers
	if workers_needed > 0:
		parentCar.update_work_maps(work_types,sequence,Globals.MODULE_ADDED)
	_update_click_area_enabled()


func _setup_click_area() -> void:
	_click_area = Area2D.new()
	_click_area.name = "ClickArea"
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(Globals.module_width, Globals.module_height)
	shape_node.shape = shape
	shape_node.position = Vector2(Globals.module_width * 0.5, 30.0 + Globals.module_height * 0.5)
	_click_area.add_child(shape_node)
	add_child(_click_area)
	_click_area.input_event.connect(_on_click_area_input_event)
	_update_click_area_enabled()


func update_click_area() -> void:
	_update_click_area_enabled()


func _update_click_area_enabled() -> void:
	if _click_area != null:
		var in_placement := Globals.activeUI is TrainUI and Globals.activeUI.pending_module_type != ""
		_click_area.input_pickable = type != "empty" or in_placement


func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if Globals.activeUI is TrainUI and Globals.activeUI.pending_module_type != "":
		if event is InputEventMouseButton and event.is_action_pressed("left_click"):
			Globals.activeUI.place_module_at_slot(parentCar.sequence, sequence)
			get_viewport().set_input_as_handled()
		return
	if type == "empty":
		return
	if event is InputEventMouseButton and event.is_action_pressed("left_click"):
		if _inspector != null and is_instance_valid(_inspector):
			hide_module_inspector()
		else:
			show_module_inspector()
		get_viewport().set_input_as_handled()


func show_module_inspector() -> void:
	if type == "empty":
		return
	if parentTrain != null:
		parentTrain.close_module_inspectors(self)
	hide_module_inspector()
	_inspector = INSPECTOR_SCENE.instantiate()
	add_child(_inspector)


func hide_module_inspector() -> void:
	if _inspector != null and is_instance_valid(_inspector):
		_inspector.queue_free()
	_inspector = null

func get_production_progress() -> float:
	if producers.is_empty():
		print("ModuleBase:: no producers to get progress from")
		return 0.0
	# For now only get the first production producer, assuming one per module
	var res : float = producers.get(0).progress
	return res
