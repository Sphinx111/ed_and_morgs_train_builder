extends Panel

class_name ModuleInspector

const RESOURCE_SUMMARY_SCENE: PackedScene = preload("res://Scenes/resource_summary.tscn")
const MAIN_VBOX_PATH := "MainVBox"
const PANEL_OFFSET := Vector2(-183.0, -158.0)
const INSPECTOR_Z_INDEX := 200
const ROW_HEIGHT: float = 22.0
const OCCUPANT_FONT_SIZE: int = 14

var parentModule: ModuleBase
var production_section: VBoxContainer
var workers_and_customers: HBoxContainer
var workers_section: VBoxContainer
var customers_section: VBoxContainer
var workers_list: VBoxContainer
var customers_list: VBoxContainer
var workers_label: RichTextLabel
var customers_label: RichTextLabel
var progressBar: ProgressBar
var input_resources: VBoxContainer
var output_resources: VBoxContainer
var mode_button: OptionButton
var mode_label: RichTextLabel
var enabled_toggle: CheckButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = INSPECTOR_Z_INDEX
	production_section = get_node("%s/ProductionSection" % MAIN_VBOX_PATH)
	workers_and_customers = get_node("%s/WorkersAndCustomers" % MAIN_VBOX_PATH)
	workers_section = get_node("%s/WorkersAndCustomers/WorkersSection" % MAIN_VBOX_PATH)
	customers_section = get_node("%s/WorkersAndCustomers/CustomersSection" % MAIN_VBOX_PATH)
	workers_list = get_node("%s/WorkersAndCustomers/WorkersSection/WorkersScroll/WorkersList" % MAIN_VBOX_PATH)
	customers_list = get_node("%s/WorkersAndCustomers/CustomersSection/CustomersScroll/CustomersList" % MAIN_VBOX_PATH)
	workers_label = get_node("%s/WorkersAndCustomers/WorkersSection/WorkersLabel" % MAIN_VBOX_PATH)
	customers_label = get_node("%s/WorkersAndCustomers/CustomersSection/CustomersLabel" % MAIN_VBOX_PATH)
	progressBar = get_node("%s/ProductionSection/ProductionRow/ProgressBar" % MAIN_VBOX_PATH)
	input_resources = get_node("%s/ProductionSection/ProductionRow/InputResources" % MAIN_VBOX_PATH)
	output_resources = get_node("%s/ProductionSection/ProductionRow/OutputResources" % MAIN_VBOX_PATH)
	mode_button = get_node("ControlsSection/OptionButton")
	mode_label = get_node("ControlsSection/OptionLabel")
	enabled_toggle = get_node("ControlsSection/ToggleButton")

	get_node("%s/HeaderSection/ModuleNameLabel" % MAIN_VBOX_PATH).text = parentModule.type
	var refund: float = ModuleBase.build_cost.get(parentModule.type, 0.0) * Globals.refund_module_fraction
	get_node("%s/HeaderSection/CostLabel" % MAIN_VBOX_PATH).text = "Sell: %f" % refund
	_setup_mode_dropdown()
	mode_button.item_selected.connect(_on_mode_selected)
	enabled_toggle.button_pressed = parentModule.enabled
	enabled_toggle.toggled.connect(_on_enabled_toggled)
	var exit_button := find_child("ExitButton", true, false) as Button
	if exit_button != null:
		exit_button.pressed.connect(_on_exit_pressed)
	_setup_production_resources()
	_update_section_visibility()
	update_screen_position()
	set_process(true)
	tick()


func update_screen_position() -> void:
	if parentModule == null:
		return
	global_position = parentModule.get_global_transform_with_canvas() * PANEL_OFFSET


func _process(_delta: float) -> void:
	update_screen_position()


func tick() -> void:
	if parentModule.active_producer != null:
		progressBar.value = parentModule.get_production_progress()
	_update_occupant_lists()


func on_active_producer_changed() -> void:
	_setup_production_resources()
	tick()


func _setup_mode_dropdown() -> void:
	mode_button.clear()
	var show_mode := parentModule.producers.size() > 1
	mode_label.visible = show_mode
	mode_button.visible = show_mode
	if not show_mode:
		return
	for producer in parentModule.producers:
		mode_button.add_item(producer.process_name)
	var active_index := parentModule.producers.find(parentModule.active_producer)
	if active_index >= 0:
		mode_button.select(active_index)


func _on_mode_selected(index: int) -> void:
	parentModule.set_active_producer_index(index)


func _on_enabled_toggled(toggled_on: bool) -> void:
	parentModule.set_enabled(toggled_on)


func sync_enabled_toggle() -> void:
	enabled_toggle.button_pressed = parentModule.enabled


func _on_exit_pressed() -> void:
	if parentModule != null:
		parentModule.hide_module_inspector()


func _setup_production_resources() -> void:
	_clear_container(input_resources)
	_clear_container(output_resources)
	if parentModule.active_producer == null:
		production_section.hide()
		return

	var producer: ProductionProvider = parentModule.active_producer
	production_section.show()
	progressBar.min_value = 0.0
	progressBar.max_value = 1.0
	progressBar.value = parentModule.get_production_progress()
	_add_resource_summary(input_resources, producer.input_type_1, producer.input1_needed)
	_add_resource_summary(input_resources, producer.input_type_2, producer.input2_needed)
	_add_resource_summary(output_resources, producer.output_type_1, producer.output1_amount)
	_add_resource_summary(output_resources, producer.output_type_2, producer.output2_amount)


func _update_section_visibility() -> void:
	workers_section.visible = parentModule.workers_needed > 0
	customers_section.visible = parentModule.maxCustomers > 0
	workers_and_customers.visible = workers_section.visible or customers_section.visible


func _update_occupant_lists() -> void:
	_clear_container(workers_list)
	_clear_container(customers_list)

	var worker_count := 0
	for worker in parentModule.workers:
		if is_instance_valid(worker):
			_add_passenger_label(workers_list, worker)
			worker_count += 1

	var customer_count := 0
	for customer in parentModule.customers:
		if is_instance_valid(customer):
			_add_passenger_label(customers_list, customer)
			customer_count += 1

	_update_section_labels(worker_count, customer_count)
	_update_section_visibility()


func _update_section_labels(worker_count: int, customer_count: int) -> void:
	workers_label.text = "Workers (%d/%d)" % [worker_count, parentModule.workers_needed]
	customers_label.text = "Customers (%d/%d)" % [customer_count, parentModule.maxCustomers]


func _add_passenger_label(container: VBoxContainer, passenger: Passenger) -> void:
	var label := RichTextLabel.new()
	label.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.scroll_active = false
	label.fit_content = true
	label.add_theme_font_size_override("normal_font_size", OCCUPANT_FONT_SIZE)
	label.text = "%s %s" % [passenger.firstname, passenger.lastname]
	container.add_child(label)


func _add_resource_summary(container: VBoxContainer, resource_type: ResourceType, amount: float) -> void:
	if resource_type == null or amount <= 0.0:
		return
	var summary: ResourceSummary = RESOURCE_SUMMARY_SCENE.instantiate()
	summary.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	summary.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	container.add_child(summary)
	summary.setup(resource_type, amount)


func _clear_container(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()
