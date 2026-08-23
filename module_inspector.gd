extends Panel

class_name ModuleInspector

const RESOURCE_SUMMARY_SCENE: PackedScene = preload("res://Scenes/resource_summary.tscn")

var parentModule: ModuleBase
var production_section: Control
var progressBar: ProgressBar
var input_resources: VBoxContainer
var output_resources: VBoxContainer


func _ready() -> void:
	parentModule = get_parent() as ModuleBase
	get_node("ModuleNameLabel").text = parentModule.type
	var refund: float = ModuleBase.build_cost.get(parentModule.type, 0.0) * Globals.refund_module_fraction
	get_node("CostLabel").text = "Sell: %f" % refund
	production_section = get_node("ProductionSection")
	progressBar = get_node("ProductionSection/ProductionRow/ProgressBar")
	input_resources = get_node("ProductionSection/ProductionRow/InputResources")
	output_resources = get_node("ProductionSection/ProductionRow/OutputResources")
	_setup_production_resources()


func tick() -> void:
	if parentModule.producers.is_empty():
		return
	progressBar.value = parentModule.get_production_progress()


func _setup_production_resources() -> void:
	_clear_container(input_resources)
	_clear_container(output_resources)
	if parentModule.producers.is_empty():
		production_section.hide()
		return
	var producer : ProductionProvider = parentModule.producers.get(0)
	production_section.show()
	progressBar.min_value = 0.0
	progressBar.max_value = 1.0
	progressBar.value = parentModule.get_production_progress()
	_add_resource_summary(input_resources, producer.input_type_1, producer.input1_needed)
	_add_resource_summary(input_resources, producer.input_type_2, producer.input2_needed)
	_add_resource_summary(output_resources, producer.output_type_1, producer.output1_amount)
	_add_resource_summary(output_resources, producer.output_type_2, producer.output2_amount)


func _add_resource_summary(container: VBoxContainer, resource_type: ResourceType, amount: float) -> void:
	if resource_type == null or amount <= 0.0:
		return
	var summary: ResourceSummary = RESOURCE_SUMMARY_SCENE.instantiate()
	container.add_child(summary)
	summary.setup(resource_type, amount)


func _clear_container(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()
