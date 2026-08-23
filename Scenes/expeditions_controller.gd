extends Panel

class_name ExpeditionsController

var options_available : Array[ExpeditionOption] = []
var expeditions_active : Array[ActiveExpedition] = []
var expeditions_awaiting_cleanup : Array[ActiveExpedition] = []
var selectedTrain : Train = null
var active_expeditions_panel : Panel = null
var available_expeditions_panel : Panel = null
var available_label : Label = null
var active_label : Label = null

const height_of_option : float = 31.0
const separation_between_options : float = 4.0
const panel_margin : float = 4.0
const bottom_control_padding : float = 40.0
const section_label_height : float = 23.0
const section_label_gap : float = 3.0
const section_spacing : float = 2.0
const outer_panel_width : float = 652.0
const inner_panel_width : float = 644.0

signal expeditions_finished 
signal expeditions_started

func _ready():
	active_expeditions_panel = get_node("ActiveExpeditionsPanel")
	available_expeditions_panel = get_node("OptionsPanel")
	available_label = get_node("Label")
	active_label = get_node("Label2")
	selectedTrain = get_parent().selectedTrain
	
	expeditions_finished.connect(selectedTrain.receive_expeditions_finished_signal)
	expeditions_started.connect(selectedTrain.receive_expeditions_started_signal)
	
	refresh_options()

func _panel_height_for_count(count : int) -> float:
	return (count * (height_of_option + separation_between_options)) + separation_between_options

func _update_panel_layout() -> void:
	var option_count : int = maxi(1, options_available.size())
	var active_count : int = clampi(maxi(1, expeditions_active.size()), 1, Globals.MAX_EXPEDITIONS)
	
	var options_height : float = _panel_height_for_count(option_count)
	var active_height : float = _panel_height_for_count(active_count)
	
	var y : float = panel_margin
	available_label.position = Vector2(panel_margin, y)
	y += section_label_height + section_label_gap
	
	available_expeditions_panel.position = Vector2(panel_margin, y)
	available_expeditions_panel.size = Vector2(inner_panel_width, options_height)
	y += options_height + section_spacing
	
	active_label.position = Vector2(panel_margin, y)
	y += section_label_height + section_label_gap
	
	active_expeditions_panel.position = Vector2(panel_margin, y)
	active_expeditions_panel.size = Vector2(inner_panel_width, active_height)
	y += active_height + bottom_control_padding
	
	size = Vector2(outer_panel_width, y)

func refresh_options():
	options_available.clear()
	var containers_in_range : Array[MapResourceContainer] = selectedTrain.worldMap.query_resource_types()
	for child in available_expeditions_panel.get_children():
		if child is ExpeditionOption:
			child.queue_free()
	
	var option_index : int = 0
	for container in containers_in_range:
		var resourceType : String = container.resource_type
		var newOption : ExpeditionOption = ExpeditionOption.new_expedition(resourceType, container)
		options_available.append(newOption)
		available_expeditions_panel.add_child(newOption)
		newOption.position.y = (option_index * (height_of_option + separation_between_options)) + separation_between_options
		option_index += 1
	
	for location in selectedTrain.worldMap.query_scavenge_locations():
		var scavengeOption : ExpeditionOption = ExpeditionOption.new_scavenge_expedition(location)
		options_available.append(scavengeOption)
		available_expeditions_panel.add_child(scavengeOption)
		scavengeOption.position.y = (option_index * (height_of_option + separation_between_options)) + separation_between_options
		option_index += 1
	
	_update_panel_layout()

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
	
	if expeditions_active.size() >= Globals.MAX_EXPEDITIONS:
		return Globals.EXCEEDS_MAX_EXPEDITIONS
	
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
	_reposition_active_expeditions()
	_update_panel_layout()
	return Globals.RESULT_OK

func _reposition_active_expeditions() -> void:
	for i in range(expeditions_active.size()):
		expeditions_active[i].position.y = (i * (height_of_option + separation_between_options)) + separation_between_options

func train_tick():
	var initial_count : int = expeditions_active.size()

	for expedition in expeditions_active:
		expedition.train_tick()
		if expedition.time_passed >= expedition.total_duration:
			complete_expedition(expedition)
			expeditions_awaiting_cleanup.append(expedition)
	
	var cleanup_count : int = expeditions_awaiting_cleanup.size()
	for toDelete in expeditions_awaiting_cleanup:
		expeditions_active.erase(toDelete)
		toDelete.queue_free()
	expeditions_awaiting_cleanup = []
	
	if cleanup_count > 0:
		_reposition_active_expeditions()
		_update_panel_layout()
	
	if initial_count > 0 and expeditions_active.size() == 0:
		expeditions_finished.emit()              ## If we have just finished all expeditions, emit a signal

func complete_expedition(completed : ActiveExpedition):
	if completed.is_scavenge:
		if completed.scavenge_location != null:
			completed.scavenge_location.discover_random_resource()
		refresh_options()
	else:
		for key in completed.resources_gathered.keys():
			selectedTrain.add_res(key, completed.resources_gathered[key])
	selectedTrain.recover_expedition(completed.passengers)

func abandon_expedition(abandoned : ActiveExpedition):
	expeditions_active.erase(abandoned)
	if expeditions_active.size() == 0:
		expeditions_finished.emit()
	abandoned.queue_free()
	_reposition_active_expeditions()
	_update_panel_layout()
