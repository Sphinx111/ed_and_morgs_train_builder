extends Panel

class_name ModuleInspector

var parentModule : ModuleBase
var progressBar : ProgressBar

func _ready()-> void:
	parentModule = get_parent() as ModuleBase
	get_node("ModuleNameLabel").text = parentModule.type
	var refund : float = ModuleBase.build_cost.get(parentModule.type, 0.0) * Globals.refund_module_fraction
	get_node("CostLabel").text = "Sell: %f" % refund
	progressBar = get_node("ProductionSection/ProgressBar")
	progressBar.min_value = 0.0
	progressBar.max_value = 1.0
	progressBar.value = parentModule.get_production_progress()

func tick()-> void:
	progressBar.value = parentModule.get_production_progress()
