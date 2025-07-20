extends Panel

class_name ExpeditionsController

var options_available : Array[ExpeditionOption] = []
var expeditions_active : Array[ActiveExpedition] = []
var expeditions_awaiting_cleanup : Array[ActiveExpedition] = []
var selectedTrain : Train = null
var active_expeditions_panel : Panel = null

func _ready():
	active_expeditions_panel = get_node("ActiveExpeditionsPanel")
	selectedTrain = get_parent().selectedTrain

func dispatch_expedition(typeToStart : ExpeditionOption):
	# Check if there are sufficient resources to launch the expedition
	var can_launch : bool = true
	for cost in typeToStart.costs:
		if selectedTrain.get_res(cost[0]) < cost[1] * typeToStart.pop_allocated:
			can_launch = false
	
	if can_launch == false:
		return Globals.NO_RESOURCES
	
	var index_to_use : int = 1
	for expedition in expeditions_active:
		if expedition.original_name == typeToStart.display_name:
			index_to_use += 1
	var passengersArray = selectedTrain.get_expedition_team(typeToStart.pop_allocated)
	var new_expedition : ActiveExpedition = ActiveExpedition.new_expedition(index_to_use, typeToStart, passengersArray)
	expeditions_active.append(new_expedition)
	active_expeditions_panel.add_child(new_expedition)
	return Globals.RESULT_OK

func train_tick():
	for expedition in expeditions_active:
		expedition.train_tick()
		if expedition.time_passed >= expedition.total_duration:
			complete_expedition(expedition)
			expeditions_awaiting_cleanup.append(expedition)
	
	for toDelete in expeditions_awaiting_cleanup:
		expeditions_active.erase(toDelete)
		toDelete.queue_free()
	

func complete_expedition(completed : ActiveExpedition):
	for key in completed.resources_gathered.keys():
		selectedTrain.add_res(key, completed.resources_gathered[key])
	selectedTrain.recover_expedition(completed.passengers)
	
