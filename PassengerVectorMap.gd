extends Node

class_name PassengerVectorMap

const NO_DIRECTION : float = 9999.0
const max_work_travel_dist : int = 5
const max_needs_travel_dist : int = 10
const all_needs_list : Array[String] = Globals.needs_groups
const all_work_types_list : Array[String] = Globals.work_types

var work_locations_map : Dictionary = {}
var needs_locations_map : Dictionary = {}

var work_vectors_map : Dictionary = {}
var needs_vectors_map : Dictionary = {}

var train : Train = null


func set_train(new_train : Train) -> void:
	train = new_train


func init_maps() -> void:
	for need in all_needs_list:
		_rebuild_need_map(need)
	for work_type in all_work_types_list:
		_rebuild_work_map(work_type)


func rebuild_maps() -> void:
	init_maps()


func resize_maps() -> void:
	rebuild_maps()


func modify_needs_maps(need_types : Array[String], train_pos : Array[int], new_state : int) -> void:
	for need in need_types:
		_update_need_location(need, train_pos, new_state)
		needs_vectors_map[need] = build_vector_map(needs_locations_map[need], false)


func modify_work_maps(work_types : Array[String], train_pos : Array[int], new_state : int) -> void:
	for work_type in work_types:
		_update_work_location(work_type, train_pos, new_state)
		work_vectors_map[work_type] = build_vector_map(work_locations_map[work_type], true)


func has_work_for_type(test_type : String) -> bool:
	if not work_locations_map.has(test_type):
		return false
	for cell_value in work_locations_map[test_type]:
		if cell_value == 1:
			return true
	return false


## Returns signed pull toward the nearest goal module at this train position.
## Positive pulls right along the train, negative pulls left, 0.0 means already at a goal module.
func get_travel_pull_at(position : Array[int], goal_type : String, map_kind : String) -> float:
	var index : int = Helpers.coords_to_index(position)
	var vectors : Array = _get_vectors_for_kind(goal_type, map_kind)
	if vectors.is_empty() or index < 0 or index >= vectors.size():
		return NO_DIRECTION
	return float(vectors[index])


## Rebuild a flat vector field from a flat location map.
## Each cell stores signed distance to the nearest available target within range, or NO_DIRECTION.
func build_vector_map(locations_map : Array[int], is_work_map : bool) -> Array[float]:
	var max_range_of_search : int = max_work_travel_dist if is_work_map else max_needs_travel_dist
	if locations_map.is_empty():
		return []

	var target_indices : Array[int] = []
	for i in range(locations_map.size()):
		if locations_map[i] == 1:
			target_indices.append(i)
	if target_indices.is_empty():
		return []

	var flat_vectors : Array[float] = []
	flat_vectors.resize(locations_map.size())

	for i in range(locations_map.size()):
		if locations_map[i] == 1:
			flat_vectors[i] = 0.0
			continue

		var best_distance : int = max_range_of_search + 1
		var best_direction : float = NO_DIRECTION
		for target_index in target_indices:
			var signed_distance : int = target_index - i
			var distance : int = absi(signed_distance)
			if distance > max_range_of_search:
				continue
			if distance < best_distance:
				best_distance = distance
				best_direction = float(signed_distance)
			elif distance == best_distance and signed_distance < int(best_direction):
				best_direction = float(signed_distance)

		flat_vectors[i] = best_direction

	return flat_vectors


func _rebuild_need_map(need : String) -> void:
	needs_locations_map[need] = train.get_location_map_for_type(need)
	needs_vectors_map[need] = build_vector_map(needs_locations_map[need], false)


func _rebuild_work_map(work_type : String) -> void:
	work_locations_map[work_type] = train.get_work_location_map_for_type(work_type)
	work_vectors_map[work_type] = build_vector_map(work_locations_map[work_type], true)


func _update_need_location(need : String, train_pos : Array[int], new_state : int) -> void:
	if _should_patch_location(need, train_pos, new_state, false):
		_set_location_cell(needs_locations_map[need], train_pos, new_state)
	else:
		needs_locations_map[need] = train.get_location_map_for_type(need)


func _update_work_location(work_type : String, train_pos : Array[int], new_state : int) -> void:
	if _should_patch_location(work_type, train_pos, new_state, true):
		_set_location_cell(work_locations_map[work_type], train_pos, new_state)
	else:
		work_locations_map[work_type] = train.get_work_location_map_for_type(work_type)


func _should_patch_location(type_key : String, train_pos : Array[int], new_state : int, is_work : bool) -> bool:
	var module : ModuleBase = _get_module_at(train_pos)
	if module == null:
		return false
	if is_work:
		return _module_provides_work(module, type_key)
	return module.can_serve_need(type_key)


func _set_location_cell(locations_map : Array[int], train_pos : Array[int], value : int) -> void:
	var index : int = Helpers.coords_to_index(train_pos)
	if index >= 0 and index < locations_map.size():
		locations_map[index] = value


func _get_module_at(train_pos : Array[int]) -> ModuleBase:
	if train_pos[0] < 0 or train_pos[0] >= train.carriages.size():
		return null
	var carriage : TraincarBase = train.carriages[train_pos[0]]
	if carriage == null or train_pos[1] < 0 or train_pos[1] >= Globals.modules_per_car:
		return null
	return carriage.modules[train_pos[1]]


func _module_provides_work(module : ModuleBase, work_type : String) -> bool:
	if work_type == "any":
		return module.workers_needed > 0
	return module.work_types.has(work_type)


func _get_vectors_for_kind(type : String, map_kind : String) -> Array:
	if map_kind == "need" and needs_vectors_map.has(type):
		return needs_vectors_map[type]
	if map_kind == "work" and work_vectors_map.has(type):
		return work_vectors_map[type]
	return []
