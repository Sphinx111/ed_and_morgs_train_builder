extends Panel

class_name JobsController

var passengerManager : PassengerManager = null

var priorities : Array[JobPriorityItem] = []

func init_control():
	passengerManager = get_parent().selectedTrain.passengerManager
	if passengerManager == null:
		print_debug("passenger Manager null")
		return
	for child in get_children():
		if child is JobPriorityItem:
			priorities.append(child)
	priorities.sort_custom(_initial_sort)
	
	for i in range(priorities.size()):
		priorities[i]._change_index(i)

## Custom function to sort our objects to match the priority order in the passengerManager
func _initial_sort(a, b):
	var sourceArray = passengerManager.work_priorities
	var a_priority = sourceArray.find(a.myType)
	var b_priority = sourceArray.find(b.myType)
	
	# If one of the items doesn't exist, the other one should be higher priority
	if a_priority == -1:
		return false
	elif b_priority == -1:
		return true
	if a_priority < b_priority:
		return true
	return false

func is_job_of_type(testJob : JobPriorityItem, testType : String) -> bool:
	if testJob.myType == testType:
		return true
	return false

func _on_job_increase_pressed(cur_index : int):
	if cur_index == 0:
		return
	
	var new_index = cur_index - 1
	var node_to_swap = priorities[new_index]
	var current_node = priorities[cur_index]
	priorities[new_index] = priorities[cur_index]
	priorities[cur_index] = node_to_swap
	current_node._change_index(new_index)
	node_to_swap._change_index(cur_index)
	pass

func _on_job_decrease_pressed(cur_index : int):
	if cur_index == priorities.size() - 1:
		return
	var new_index = cur_index + 1
	var node_to_swap = priorities[new_index]
	var current_node = priorities[cur_index]
	priorities[new_index] = priorities[cur_index]
	priorities[cur_index] = node_to_swap
	current_node._change_index(new_index)
	node_to_swap._change_index(cur_index)
	pass
