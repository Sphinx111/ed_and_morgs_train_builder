extends Panel

class_name ExpeditionsController

var options_available : Array[ExpeditionOption] = []
var expeditions_active : Array[ActiveExpedition] = []
var expeditions_awaiting_cleanup : Array[ActiveExpedition] = []
var selectedTrain : Train = null
var active_expeditions_panel : Panel = null
var available_expeditions_panel : Panel = null
const height_of_option : float = 31.0
const separation_between_options : float = 4.0

signal expeditions_finished 
signal expeditions_started

func _ready():
	active_expeditions_panel = get_node("ActiveExpeditionsPanel")
	available_expeditions_panel = get_node("OptionsPanel")
	selectedTrain = get_parent().selectedTrain
	
	expeditions_finished.connect(selectedTrain.receive_expeditions_finished_signal)
	expeditions_started.connect(selectedTrain.receive_expeditions_started_signal)
	
	refresh_options()

func refresh_options():
	var result : Dictionary = selectedTrain.worldMap.query_resource_types()
	var resource_types_in_range : Array[String] = result.keys()
	for child in available_expeditions_panel.get_children():
		if child is ExpeditionOption:
			child.queue_free()
	
	for i in range(resource_types_in_range.size()):
		var resourceType : String = resource_types_in_range[i]
		var expedition_name : String = ""
		if resourceType == "pop":
			expedition_name = "Find Survivors"
		elif resourceType == "scrap":
			expedition_name = "Fetch Scrap"
		elif resourceType == "grey_water":
			expedition_name = "Fetch Water"
		elif resourceType == "oil":
			expedition_name = "Fetch Oil"
		
		if resourceType == "pop" or resourceType == "scrap" or resourceType == "grey_water" or resourceType == "oil":
			var newOption : ExpeditionOption = ExpeditionOption.new_expedition(expedition_name, resourceType, result.get(resourceType))
			options_available.append(newOption)
			available_expeditions_panel.add_child(newOption)
			newOption.position.y = (i * (height_of_option + separation_between_options)) + separation_between_options

func dispatch_expedition(typeToStart : ExpeditionOption) -> int:
	# an expidition can only be launched when the train is stopped
	if selectedTrain.speed > 0:
		return Globals.EXCEEDS_MAX_SPEED
	
	# Check if there are sufficient resources to launch the expedition
	var can_launch : bool = true
	for cost in typeToStart.costs:
		if selectedTrain.get_res(cost[0]) < cost[1] * typeToStart.pop_allocated:
			can_launch = false
	
	if can_launch == false:
		return Globals.NO_RESOURCES
	
	if expeditions_active.size() == 0:
		expeditions_started.emit()
	
	for cost in typeToStart.costs:
		selectedTrain.add_res(cost[0], -cost[1] * typeToStart.pop_allocated)
	
	var index_to_use : int = 1
	for expedition in expeditions_active:
		if expedition.original_name == typeToStart.display_name:
			index_to_use += 1
	var passengersArray = selectedTrain.get_expedition_team(typeToStart.pop_allocated)
	var new_expedition : ActiveExpedition = ActiveExpedition.new_expedition(index_to_use, typeToStart, passengersArray)
	expeditions_active.append(new_expedition)
	active_expeditions_panel.add_child(new_expedition)
	new_expedition.position.y = ((expeditions_active.size() - 1) * (height_of_option + separation_between_options)) + separation_between_options
	return Globals.RESULT_OK

func train_tick():
	var initial_count : int = expeditions_active.size()

	for expedition in expeditions_active:
		expedition.train_tick()
		if expedition.time_passed >= expedition.total_duration:
			complete_expedition(expedition)
			expeditions_awaiting_cleanup.append(expedition)
	
	for toDelete in expeditions_awaiting_cleanup:
		expeditions_active.erase(toDelete)
		toDelete.queue_free()
	expeditions_awaiting_cleanup = []
	
	if initial_count > 0 and expeditions_active.size() == 0:
		expeditions_finished.emit()              ## If we have just finished all expeditions, emit a signal

func complete_expedition(completed : ActiveExpedition):
	for key in completed.resources_gathered.keys():
		selectedTrain.add_res(key, completed.resources_gathered[key])
	selectedTrain.recover_expedition(completed.passengers)

func abandon_expedition(abandoned : ActiveExpedition):
	expeditions_active.erase(abandoned)
	if expeditions_active.size() == 0:
		expeditions_finished.emit()
	abandoned.queue_free()
