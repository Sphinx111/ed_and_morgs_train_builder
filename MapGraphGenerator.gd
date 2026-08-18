@tool
extends Node2D

## Procedural world map generation: main spine, town branches, villages on edges, angle cleanup.
class_name MapGraphGenerator

class TownChain:
	var towns: Array[MapLocation] = []
	var entry_city: MapLocation = null
	var exit_city: MapLocation = null


@export var numOfCities: int = 6
@export var numOfTowns: int = 14
@export var numOfVillages: int = 21

@export var min_distance: float = 80.0
@export var town_min_distance: float = 80.0
@export var village_min_distance: float = 30.0
@export var min_horizontal_distance: float = 70.0
@export var placement_passes: int = 20
@export var towns_per_branch: int = 6 ## Target number of towns in each branch chain
@export var sharp_angle_threshold: float = 45.0 ## Minimum allowed angle in degrees between edges at a node
@export var village_variability: float = 0.2 ## Random variation applied to each branch's share of the village budget
@export var village_edge_offset_ratio: float = 0.12 ## Perpendicular kink offset as a fraction of edge length
@export var min_edge_length_for_village: float = 40.0
@export var max_trunk_villages: int = 5
@export var max_villages_per_branch: int = 4 ## Maximum villages placed on each town branch chain

const SHARP_ANGLE_MOVE_STEP: float = 8.0
const SHARP_ANGLE_MAX_STEPS: int = 10
const SHARP_ANGLE_MAX_PASSES: int = 4
const EDGE_CROSSING_MAX_PASSES: int = 12
const GENERATION_SOFT_TIMEOUT_MS: int = 200
const GENERATION_HARD_TIMEOUT_MS: int = 2000

var allNodes: Array[MapLocation] = []
var mapSize: Vector2 = Vector2(1024, 724)
var margins: float = 50.0
@export var city_vertical_band: float = 0.4 ## Middle fraction of map height for cities and loopers
@export var town_vertical_band: float = 0.7 ## Middle fraction of map height for towns
var looper_height_helper: float = 0.0
var _town_branches: Array[TownChain] = []
var _generation_session: Dictionary = {}


func regenerate_map() -> MapGraph:
	var total_start_ms: int = Time.get_ticks_msec()
	var graph: MapGraph

	if _run_generation_attempt(1, true):
		_log_generation_time(total_start_ms)
		graph = extract_map_graph()
	else:
		print(
			"MapGraphGenerator: first generation attempt exceeded %d ms, restarting"
			% GENERATION_SOFT_TIMEOUT_MS
		)

		if _run_generation_attempt(2, false):
			_log_generation_time(total_start_ms)
			graph = extract_map_graph()
		else:
			push_error(
				"MapGraphGenerator: generation did not complete within %d ms on the second attempt"
				% GENERATION_HARD_TIMEOUT_MS
			)
			graph = extract_map_graph()

	return graph


## Returns the generated graph without copying nodes or edges.
## The arrays are new; the MapLocation and MapGraphEdge instances are the originals,
## so each node's edges array and each edge's node1/node2 still point at each other.
func extract_map_graph() -> MapGraph:
	return MapGraph.from_nodes(allNodes)


func _run_generation_attempt(attempt_number: int, enforce_soft_timeout: bool) -> bool:
	_begin_generation_session(attempt_number, enforce_soft_timeout)
	looper_height_helper = 0.0
	_clear_generated_nodes()

	var completed: bool = _run_generation_pipeline()
	_end_generation_session()
	return completed


func _run_generation_pipeline() -> bool:
	if _generation_checkpoint():
		return false

	first_pass()
	if _generation_checkpoint():
		return false

	second_pass()
	if _generation_checkpoint():
		return false

	third_pass()
	if _generation_checkpoint():
		return false

	_resolve_sharp_angles()
	if _generation_checkpoint():
		return false

	_resolve_edge_crossings()
	if _generation_checkpoint():
		return false

	return true


func _begin_generation_session(attempt_number: int, enforce_soft_timeout: bool) -> void:
	_generation_session = {
		"attempt": attempt_number,
		"start_ms": Time.get_ticks_msec(),
		"enforce_soft_timeout": enforce_soft_timeout,
		"hard_timeout": false,
	}


func _end_generation_session() -> void:
	_generation_session.clear()


func _generation_checkpoint() -> bool:
	if _generation_session.is_empty():
		return false

	var elapsed_ms: int = Time.get_ticks_msec() - _generation_session["start_ms"]
	if _generation_session["enforce_soft_timeout"]:
		return elapsed_ms >= GENERATION_SOFT_TIMEOUT_MS

	if elapsed_ms >= GENERATION_HARD_TIMEOUT_MS:
		_generation_session["hard_timeout"] = true
		return true

	return false


func _log_generation_time(total_start_ms: int) -> void:
	var elapsed_ms: int = Time.get_ticks_msec() - total_start_ms
	print("MapGraphGenerator.regenerate_map took %d ms" % elapsed_ms)


# --- Pass one: loopers, cities, and the main spine -----------------------------------------------

func first_pass() -> void:
	allNodes.clear()
	add_map_looper("left")
	for i in range(numOfCities):
		if _generation_checkpoint():
			return
		var city_pos: Variant = _pick_map_pos_with_min_city_distance()
		if city_pos == null:
			continue
		_add_map_node(MapLocation.new(MapLocation.TYPE.CITY, city_pos))
	add_map_looper("right")
	connect_loopers_across_map()


func connect_loopers_across_map() -> void:
	var loopers: Array[MapLocation] = _get_looper_nodes()
	if loopers.size() < 2:
		push_error("MapGraphGenerator: expected two looper nodes")
		return

	var left_looper: MapLocation = loopers[0]
	var right_looper: MapLocation = loopers[loopers.size() - 1]
	var cities: Array[MapLocation] = _get_city_nodes()
	var route: Array[MapLocation] = _build_non_crossing_route(left_looper, cities, right_looper)

	for i in range(route.size() - 1):
		_connect_nodes(route[i], route[i + 1], MapGraphEdge.EdgeType.TRUNK)


# --- Pass two: town branches off the main city spine --------------------------------------------

func second_pass() -> void:
	_town_branches.clear()
	var towns: Array[MapLocation] = _place_all_towns()
	if towns.is_empty():
		return

	var main_route: Array[MapLocation] = _get_main_branch_route()
	var cities: Array[MapLocation] = _get_main_branch_cities()
	if main_route.size() < 2 or cities.is_empty():
		return

	var branches: Array[TownChain] = _build_town_branches(towns, main_route, cities)
	_sort_branches_for_connection(branches)
	_town_branches = branches
	for branch in branches:
		if _generation_checkpoint():
			return
		_connect_town_branch(branch)

	_connect_nearby_unlinked_towns()


func _sort_branches_for_connection(branches: Array[TownChain]) -> void:
	branches.sort_custom(func(branch_a: TownChain, branch_b: TownChain) -> bool:
		if branch_a.towns.is_empty():
			return false
		if branch_b.towns.is_empty():
			return true
		return branch_a.towns[0].position.x < branch_b.towns[0].position.x
	)


func _place_all_towns() -> Array[MapLocation]:
	var towns: Array[MapLocation] = []
	for i in range(numOfTowns):
		if _generation_checkpoint():
			return towns
		var town_pos: Variant = _pick_map_pos_with_min_town_distance()
		if town_pos == null:
			continue
		var town: MapLocation = MapLocation.new(MapLocation.TYPE.TOWN, town_pos)
		_add_map_node(town)
		towns.append(town)
	return towns


func _build_town_branches(
	towns: Array[MapLocation],
	main_route: Array[MapLocation],
	cities: Array[MapLocation]
) -> Array[TownChain]:
	var branches: Array[TownChain] = []
	if towns.is_empty() or cities.is_empty():
		return branches

	var above_towns: Array[MapLocation] = []
	var below_towns: Array[MapLocation] = []

	for town in towns:
		var segment_index: int = _get_route_segment_index_at_x(main_route, town.position.x)
		var branch_y: float = _get_branch_y_at_x(main_route, segment_index, town.position.x)
		if town.position.y < branch_y:
			above_towns.append(town)
		else:
			below_towns.append(town)

	for side_towns in [above_towns, below_towns]:
		branches.append_array(_build_side_branches(side_towns, cities))

	return branches


func _build_side_branches(towns: Array[MapLocation], cities: Array[MapLocation]) -> Array[TownChain]:
	var branches: Array[TownChain] = []
	if towns.is_empty() or cities.is_empty():
		return branches

	if cities.size() == 1:
		branches.append_array(_chunk_towns_into_branches(towns, cities[0], cities[0]))
		return branches

	var segment_towns: Array[Array] = []
	for i in range(cities.size() - 1):
		segment_towns.append([] as Array[MapLocation])

	for town in towns:
		var segment_index: int = _get_city_pair_segment_index(town, cities)
		segment_towns[segment_index].append(town)

	for segment_index in range(segment_towns.size()):
		var towns_in_segment: Array = segment_towns[segment_index]
		if towns_in_segment.is_empty():
			continue
		branches.append_array(
			_chunk_towns_into_branches(
				towns_in_segment,
				cities[segment_index],
				cities[segment_index + 1]
			)
		)

	return branches


func _get_city_pair_segment_index(town: MapLocation, cities: Array[MapLocation]) -> int:
	for i in range(cities.size() - 1):
		var segment_min_x: float = minf(cities[i].position.x, cities[i + 1].position.x)
		var segment_max_x: float = maxf(cities[i].position.x, cities[i + 1].position.x)
		if town.position.x >= segment_min_x and town.position.x <= segment_max_x:
			return i

	if town.position.x < cities[0].position.x:
		return 0
	return cities.size() - 2


func _chunk_towns_into_branches(
	towns: Array[MapLocation],
	entry_city: MapLocation,
	exit_city: MapLocation
) -> Array[TownChain]:
	var branches: Array[TownChain] = []
	if towns.is_empty():
		return branches

	var branch_size: int = maxi(2, towns_per_branch)
	var sorted_towns: Array[MapLocation] = _sort_nodes_by_x(towns)
	var chunk_start: int = 0

	while chunk_start < sorted_towns.size():
		var chunk_end: int = mini(chunk_start + branch_size, sorted_towns.size())
		var chunk: Array[MapLocation] = sorted_towns.slice(chunk_start, chunk_end)
		branches.append(_make_town_branch(chunk, entry_city, exit_city))
		chunk_start = chunk_end

	return branches


func _make_town_branch(
	towns: Array[MapLocation],
	entry_city: MapLocation,
	exit_city: MapLocation
) -> TownChain:
	var branch := TownChain.new()
	branch.towns = _sort_nodes_by_x(towns)
	branch.entry_city = entry_city
	branch.exit_city = exit_city
	return branch


func _get_main_branch_route() -> Array[MapLocation]:
	var loopers: Array[MapLocation] = _get_looper_nodes()
	if loopers.size() < 2:
		return []
	var cities: Array[MapLocation] = _get_city_nodes()
	return _build_non_crossing_route(loopers[0], cities, loopers[loopers.size() - 1])


func _get_route_segment_index_at_x(route: Array[MapLocation], x: float) -> int:
	for i in range(route.size() - 1):
		var segment_min_x: float = minf(route[i].position.x, route[i + 1].position.x)
		var segment_max_x: float = maxf(route[i].position.x, route[i + 1].position.x)
		if x >= segment_min_x and x <= segment_max_x:
			return i

	if x < route[0].position.x:
		return 0
	return route.size() - 2


func _get_branch_y_at_x(route: Array[MapLocation], segment_index: int, x: float) -> float:
	var start_pos: Vector2 = route[segment_index].position
	var end_pos: Vector2 = route[segment_index + 1].position
	if is_equal_approx(start_pos.x, end_pos.x):
		return start_pos.y
	var t: float = (x - start_pos.x) / (end_pos.x - start_pos.x)
	return lerpf(start_pos.y, end_pos.y, t)


func _connect_town_branch(branch: TownChain) -> void:
	if branch.towns.is_empty() or branch.entry_city == null or branch.exit_city == null:
		return

	_uncross_branch_town_order(branch)
	var route: Array[MapLocation] = _get_branch_route(branch)

	for i in range(route.size() - 1):
		_try_connect_nodes(
			route[i],
			route[i + 1],
			true,
			MapGraphEdge.EdgeType.BRANCH
		)


func _connect_nearby_unlinked_towns() -> void:
	var cities: Array[MapLocation] = _get_city_nodes()
	var towns: Array[MapLocation] = _get_town_nodes()

	for town in towns:
		if town.edges.size() != 2:
			continue

		var nearest_city_distance: float = _get_nearest_city_distance(town, cities)
		var nearest_town: MapLocation = _find_nearest_unconnected_town_closer_than(
			town,
			towns,
			nearest_city_distance
		)
		if nearest_town == null:
			continue

		_try_connect_nodes(town, nearest_town, true, MapGraphEdge.EdgeType.BRANCH)


func _get_nearest_city_distance(town: MapLocation, cities: Array[MapLocation]) -> float:
	var nearest_distance: float = INF
	for city in cities:
		nearest_distance = minf(
			nearest_distance,
			town.position.distance_to(city.position)
		)
	return nearest_distance


func _find_nearest_unconnected_town_closer_than(
	town: MapLocation,
	towns: Array[MapLocation],
	nearest_city_distance: float
) -> MapLocation:
	var nearest_town: MapLocation = null
	var nearest_town_distance: float = nearest_city_distance

	for other_town in towns:
		if other_town == town:
			continue
		if _nodes_are_connected(town, other_town):
			continue

		var distance: float = town.position.distance_to(other_town.position)
		if distance >= nearest_town_distance:
			continue

		nearest_town_distance = distance
		nearest_town = other_town

	return nearest_town


# --- Pass three: villages kink existing branch edges --------------------------------------------

func third_pass() -> void:
	if numOfVillages <= 0:
		return

	var trunk_edges: Array[MapGraphEdge] = []
	for edge in _get_village_candidate_edges():
		if edge.type == MapGraphEdge.EdgeType.TRUNK:
			trunk_edges.append(edge)

	var trunk_village_count: int = _get_trunk_village_count(trunk_edges.size())
	var branch_village_count: int = numOfVillages - trunk_village_count

	var trunk_allocations: Array[int] = _allocate_villages_to_edges(
		trunk_edges,
		trunk_village_count,
		0.0,
		1
	)
	_apply_village_allocations(trunk_edges, trunk_allocations)

	var branch_allocations: Array[int] = _allocate_villages_to_branches(
		_town_branches,
		branch_village_count,
		village_variability
	)
	for branch_index in range(_town_branches.size()):
		if _generation_checkpoint():
			return
		_place_villages_on_town_branch(_town_branches[branch_index], branch_allocations[branch_index])


func _get_village_candidate_edges() -> Array[MapGraphEdge]:
	var candidates: Array[MapGraphEdge] = []
	var seen_keys: Dictionary = {}

	for edge in _get_all_edges():
		var node_a: MapLocation = edge.node1
		var node_b: MapLocation = edge.node2
		var edge_key: String = _undirected_edge_key(node_a, node_b)
		if seen_keys.has(edge_key):
			continue
		seen_keys[edge_key] = true

		if node_a.position.distance_to(node_b.position) < min_edge_length_for_village:
			continue

		candidates.append(edge)

	return candidates


func _get_trunk_village_count(trunk_edge_count: int) -> int:
	if trunk_edge_count <= 0 or numOfVillages <= 0:
		return 0

	var trunk_target: int = randi_range(1, maxi(1, max_trunk_villages))
	return mini(trunk_target, mini(numOfVillages, trunk_edge_count))


func _allocate_villages_to_edges(
	edges: Array[MapGraphEdge],
	total_villages: int,
	variability: float,
	max_per_edge: int
) -> Array[int]:
	return _allocate_villages_with_average(edges.size(), total_villages, variability, max_per_edge)


func _allocate_villages_to_branches(
	branches: Array[TownChain],
	total_villages: int,
	variability: float
) -> Array[int]:
	return _allocate_villages_with_average(
		branches.size(),
		total_villages,
		variability,
		max_villages_per_branch
	)


func _allocate_villages_with_average(
	slot_count: int,
	total_villages: int,
	variability: float,
	max_per_slot: int
) -> Array[int]:
	var allocations: Array[int] = []
	if slot_count <= 0 or total_villages <= 0 or max_per_slot <= 0:
		return allocations

	for _slot_index in range(slot_count):
		allocations.append(0)

	var average_per_slot: float = float(total_villages) / float(slot_count)
	for slot_index in range(slot_count):
		var modifier: float = 1.0 + randf_range(-variability, variability)
		var slot_target: int = int(round(average_per_slot * modifier))
		allocations[slot_index] = clampi(slot_target, 0, max_per_slot)

	_normalize_village_allocations(allocations, total_villages, max_per_slot)
	return allocations


func _normalize_village_allocations(
	allocations: Array[int],
	target_total: int,
	max_per_slot: int
) -> void:
	var current_total: int = 0
	for allocation in allocations:
		current_total += allocation

	var difference: int = target_total - current_total
	if difference == 0:
		return

	var slot_order: Array[int] = []
	for slot_index in range(allocations.size()):
		slot_order.append(slot_index)
	slot_order.shuffle()

	while difference > 0:
		var adjusted: bool = false
		for slot_index in slot_order:
			if allocations[slot_index] >= max_per_slot:
				continue
			allocations[slot_index] += 1
			difference -= 1
			adjusted = true
			if difference == 0:
				break
		if not adjusted:
			break

	while difference < 0:
		var adjusted: bool = false
		for slot_index in slot_order:
			if allocations[slot_index] <= 0:
				continue
			allocations[slot_index] -= 1
			difference += 1
			adjusted = true
			if difference == 0:
				break
		if not adjusted:
			break


func _place_villages_on_town_branch(branch: TownChain, village_count: int) -> void:
	if branch == null or village_count <= 0:
		return

	var base_route: Array[MapLocation] = _get_branch_route(branch)
	if base_route.size() < 2:
		return

	var segment_count: int = base_route.size() - 1
	var segment_allocations: Array[int] = _allocate_villages_with_average(
		segment_count,
		village_count,
		village_variability,
		max_villages_per_branch
	)

	for segment_index in range(segment_count):
		if _generation_checkpoint():
			return
		var villages_for_segment: int = segment_allocations[segment_index]
		if villages_for_segment <= 0:
			continue

		var segment_edges: Array[MapGraphEdge] = _get_connecting_branch_edges(
			base_route[segment_index],
			base_route[segment_index + 1]
		)
		var target_edge: MapGraphEdge = _find_longest_edge(segment_edges)
		if target_edge == null:
			continue

		_try_insert_villages_on_edge(target_edge, villages_for_segment)


func _find_longest_edge(edges: Array[MapGraphEdge]) -> MapGraphEdge:
	var best_edge: MapGraphEdge = null
	var best_length: float = -1.0

	for edge in edges:
		if edge == null or not is_instance_valid(edge):
			continue
		var edge_length: float = edge.node1.position.distance_to(edge.node2.position)
		if edge_length < min_edge_length_for_village:
			continue
		if edge_length <= best_length:
			continue
		best_length = edge_length
		best_edge = edge

	return best_edge


func _try_insert_villages_on_edge(edge: MapGraphEdge, village_count: int) -> void:
	var villages_to_place: int = mini(
		village_count,
		_get_max_villages_for_edge(edge, max_villages_per_branch)
	)
	while villages_to_place > 0:
		if _insert_villages_on_edge(edge, villages_to_place) > 0:
			return
		villages_to_place -= 1


func _get_connecting_branch_edges(from_node: MapLocation, to_node: MapLocation) -> Array[MapGraphEdge]:
	var direct_edge: MapGraphEdge = _find_edge_between(from_node, to_node)
	if direct_edge != null:
		return [direct_edge]
	return _find_branch_path_edges(from_node, to_node)


func _find_edge_between(first_node: MapLocation, second_node: MapLocation) -> MapGraphEdge:
	for edge in first_node.edges:
		if edge.node1 == second_node or edge.node2 == second_node:
			return edge
	return null


func _find_branch_path_edges(from_node: MapLocation, to_node: MapLocation) -> Array[MapGraphEdge]:
	var visited: Dictionary = {}
	visited[from_node] = true
	var queue: Array = [[from_node, []]]

	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var current_node: MapLocation = item[0]
		var path_edges: Array = item[1]

		if current_node == to_node:
			var result: Array[MapGraphEdge] = []
			for path_edge in path_edges:
				result.append(path_edge as MapGraphEdge)
			return result

		for edge in current_node.edges:
			if edge.type != MapGraphEdge.EdgeType.BRANCH:
				continue

			var other_node: MapLocation = edge.node1
			if other_node == current_node:
				other_node = edge.node2
			if visited.has(other_node):
				continue

			visited[other_node] = true
			var next_path: Array = path_edges.duplicate()
			next_path.append(edge)
			queue.append([other_node, next_path])

	return []


func _get_max_villages_for_edge(edge: MapGraphEdge, max_per_edge: int) -> int:
	var edge_length: float = edge.node1.position.distance_to(edge.node2.position)
	var length_cap: int = maxi(1, int(edge_length / village_min_distance) - 1)
	return mini(max_per_edge, length_cap)


func _apply_village_allocations(edges: Array[MapGraphEdge], allocations: Array[int]) -> void:
	for edge_index in range(edges.size()):
		var village_count: int = allocations[edge_index]
		while village_count > 0:
			var placed_count: int = _insert_villages_on_edge(edges[edge_index], village_count)
			if placed_count > 0:
				break
			village_count -= 1


func _insert_villages_on_edge(edge: MapGraphEdge, village_count: int) -> int:
	if edge == null or not is_instance_valid(edge) or village_count <= 0:
		return 0

	var node_a: MapLocation = edge.node1
	var node_b: MapLocation = edge.node2
	var edge_type: MapGraphEdge.EdgeType = edge.type
	var start_pos: Vector2 = node_a.position
	var end_pos: Vector2 = node_b.position
	var village_positions: Array[Vector2] = _build_village_positions_on_edge(
		node_a,
		node_b,
		start_pos,
		end_pos,
		village_count
	)
	if village_positions.is_empty():
		return 0

	_remove_edge(edge)

	var chain: Array[MapLocation] = [node_a]
	for village_pos in village_positions:
		var village: MapLocation = MapLocation.new(MapLocation.TYPE.VILLAGE, village_pos)
		_add_map_node(village)
		chain.append(village)
	chain.append(node_b)

	for chain_index in range(chain.size() - 1):
		_connect_nodes(chain[chain_index], chain[chain_index + 1], edge_type)

	return village_positions.size()


func _build_village_positions_on_edge(
	node_a: MapLocation,
	node_b: MapLocation,
	start_pos: Vector2,
	end_pos: Vector2,
	village_count: int
) -> Array[Vector2]:
	var edge_direction: Vector2 = (end_pos - start_pos).normalized()
	var perpendicular: Vector2 = Vector2(-edge_direction.y, edge_direction.x)
	var edge_length: float = start_pos.distance_to(end_pos)
	var offset_amount: float = clampf(
		edge_length * village_edge_offset_ratio / maxf(1.0, float(village_count) * 0.75),
		6.0,
		40.0
	)
	var offset_side: float = 1.0 if randf() > 0.5 else -1.0
	var positions: Array[Vector2] = []

	for village_index in range(village_count):
		var along_edge_t: float = float(village_index + 1) / float(village_count + 1)
		var on_edge_pos: Vector2 = start_pos.lerp(end_pos, along_edge_t)
		var village_pos: Vector2 = on_edge_pos + perpendicular * offset_amount * offset_side

		if not _is_far_enough_for_village(village_pos, [node_a, node_b], positions):
			village_pos = on_edge_pos + perpendicular * offset_amount * -offset_side
		if not _is_far_enough_for_village(village_pos, [node_a, node_b], positions):
			village_pos = on_edge_pos

		village_pos = _clamp_to_map(village_pos)
		if not _is_far_enough_for_village(village_pos, [node_a, node_b], positions):
			if positions.is_empty():
				return []
			break

		positions.append(village_pos)
		offset_side *= -1.0

	return positions


func _undirected_edge_key(node_a: MapLocation, node_b: MapLocation) -> String:
	var id_a: int = node_a.get_instance_id()
	var id_b: int = node_b.get_instance_id()
	if id_a > id_b:
		var swap_id: int = id_a
		id_a = id_b
		id_b = swap_id
	return "%d_%d" % [id_a, id_b]


func _get_branch_route(branch: TownChain) -> Array[MapLocation]:
	var route: Array[MapLocation] = [branch.entry_city]
	route.append_array(branch.towns)
	route.append(branch.exit_city)
	return route


func _uncross_branch_town_order(branch: TownChain) -> void:
	if branch.towns.size() < 2:
		return

	var route: Array[MapLocation] = _get_branch_route(branch)
	_uncross_route_2opt(route)
	branch.towns = route.slice(1, route.size() - 1)


# --- Placement helpers ---------------------------------------------------------------------------

func _pick_map_pos_with_min_city_distance() -> Variant:
	for _attempt in range(placement_passes):
		var candidate: Vector2 = pick_random_map_pos_in_vertical_band(city_vertical_band)
		if _is_far_enough_from_cities(candidate):
			return candidate
	return null


func _pick_map_pos_with_min_town_distance() -> Variant:
	for _attempt in range(placement_passes):
		var candidate: Vector2 = pick_random_map_pos_in_vertical_band(town_vertical_band)
		if _is_far_enough_for_town(candidate):
			return candidate
	return null


func _is_far_enough_from_cities(pos: Vector2) -> bool:
	for map_node in allNodes:
		if map_node.type != MapLocation.TYPE.CITY:
			continue
		if abs(pos.x - map_node.position.x) < min_horizontal_distance:
			return false
	return true


func _is_far_enough_for_town(pos: Vector2) -> bool:
	for map_node in allNodes:
		if map_node.type < MapLocation.TYPE.TOWN:
			continue
		if pos.distance_to(map_node.position) < town_min_distance:
			return false
	return true


func _is_far_enough_for_village(
	pos: Vector2,
	excluded_nodes: Array[MapLocation] = [],
	pending_positions: Array[Vector2] = []
) -> bool:
	for map_node in allNodes:
		if excluded_nodes.has(map_node):
			continue
		if map_node.type < MapLocation.TYPE.VILLAGE:
			continue
		if pos.distance_to(map_node.position) < village_min_distance:
			return false

	for pending_pos in pending_positions:
		if pos.distance_to(pending_pos) < village_min_distance:
			return false

	return true


func add_map_looper(edge: String) -> void:
	if looper_height_helper == 0.0:
		var y_range: Vector2 = _get_vertical_y_range_from_band(city_vertical_band)
		looper_height_helper = randf_range(y_range.x, y_range.y)
	var pos: Vector2 = Vector2(0.0, looper_height_helper)
	if edge == "right":
		pos.x = mapSize.x
	_add_map_node(MapLocation.new(MapLocation.TYPE.MAP_LOOPER, pos))


func pick_random_map_pos() -> Vector2:
	return Vector2(
		randf_range(margins, mapSize.x - margins),
		randf_range(margins, mapSize.y - margins)
	)


func pick_random_map_pos_in_vertical_band(center_band_proportion: float) -> Vector2:
	var y_range: Vector2 = _get_vertical_y_range_from_band(center_band_proportion)
	return Vector2(
		randf_range(margins, mapSize.x - margins),
		randf_range(y_range.x, y_range.y)
	)


func _vertical_edge_inset_from_band(center_band_proportion: float) -> float:
	return (1.0 - clampf(center_band_proportion, 0.0, 1.0)) * 0.5


func _get_vertical_y_range_from_band(center_band_proportion: float) -> Vector2:
	var inset: float = _vertical_edge_inset_from_band(center_band_proportion)
	var min_y: float = maxf(margins, mapSize.y * inset)
	var max_y: float = minf(mapSize.y - margins, mapSize.y - (mapSize.y * inset))
	return Vector2(min_y, max_y)


# --- Main-route ordering / uncrossing ------------------------------------------------------------

func _build_non_crossing_route(
	start_node: MapLocation,
	cities: Array[MapLocation],
	end_node: MapLocation
) -> Array[MapLocation]:
	var ordered_cities: Array[MapLocation] = _sort_nodes_by_x(cities)
	var route: Array[MapLocation] = [start_node]
	route.append_array(ordered_cities)
	route.append(end_node)
	_uncross_route_2opt(route)
	return route


func _uncross_route_2opt(route: Array[MapLocation]) -> void:
	var improved: bool = true
	while improved:
		improved = false
		for i in range(1, route.size() - 2):
			for j in range(i + 1, route.size() - 1):
				if not _route_segments_cross(route, i, j):
					continue
				_reverse_route_segment(route, i, j)
				improved = true
				break
			if improved:
				break


func _route_segments_cross(route: Array[MapLocation], first_edge_index: int, second_edge_index: int) -> bool:
	if second_edge_index <= first_edge_index:
		return false

	var first_start: Vector2 = route[first_edge_index - 1].position
	var first_end: Vector2 = route[first_edge_index].position
	var second_start: Vector2 = route[second_edge_index].position
	var second_end: Vector2 = route[second_edge_index + 1].position
	return _segments_intersect(first_start, first_end, second_start, second_end)


func _reverse_route_segment(route: Array[MapLocation], from_index: int, to_index: int) -> void:
	while from_index < to_index:
		var temp: MapLocation = route[from_index]
		route[from_index] = route[to_index]
		route[to_index] = temp
		from_index += 1
		to_index -= 1


# --- Sharp angle cleanup -------------------------------------------------------------------------

func _resolve_sharp_angles() -> void:
	if sharp_angle_threshold <= 0.0:
		return

	for _pass_index in range(SHARP_ANGLE_MAX_PASSES):
		if _generation_checkpoint():
			return
		var improved_any: bool = false
		for map_node in allNodes:
			if _generation_checkpoint():
				return
			if not _is_angle_adjustable_node(map_node):
				continue
			if _try_improve_node_sharp_angle(map_node):
				improved_any = true
		if not improved_any:
			break


func _is_angle_adjustable_node(map_node: MapLocation) -> bool:
	return map_node.type > MapLocation.TYPE.MAP_LOOPER and map_node.type < MapLocation.TYPE.CITY


func _try_improve_node_sharp_angle(map_node: MapLocation) -> bool:
	if map_node.edges.size() < 2:
		return false

	var current_min_angle: float = _get_min_angle_degrees_at_position(map_node.position, map_node)
	if current_min_angle >= sharp_angle_threshold:
		return false

	var sharpest_pair: Array[MapLocation] = _get_sharpest_neighbor_pair(map_node)
	if sharpest_pair.size() < 2:
		return false

	var best_position: Vector2 = map_node.position
	var best_min_angle: float = current_min_angle
	var directions: Array[Vector2] = _get_angle_improvement_directions(
		map_node,
		sharpest_pair[0],
		sharpest_pair[1]
	)

	for direction in directions:
		for step in range(1, SHARP_ANGLE_MAX_STEPS + 1):
			if _generation_checkpoint():
				return false
			var candidate_position: Vector2 = _clamp_to_map(
				map_node.position + direction * SHARP_ANGLE_MOVE_STEP * float(step)
			)
			if not _is_valid_angle_adjustment_position(map_node, candidate_position):
				continue

			var candidate_min_angle: float = _get_min_angle_degrees_at_position(
				candidate_position,
				map_node
			)
			if candidate_min_angle <= best_min_angle:
				continue

			best_min_angle = candidate_min_angle
			best_position = candidate_position
			if candidate_min_angle >= sharp_angle_threshold:
				break

	if best_position.is_equal_approx(map_node.position):
		return false

	map_node.position = best_position
	_update_node_edges(map_node)
	return true


func _get_neighbor_nodes(map_node: MapLocation) -> Array[MapLocation]:
	var neighbors: Array[MapLocation] = []
	for edge in map_node.edges:
		var other_node: MapLocation = edge.node1
		if other_node == map_node:
			other_node = edge.node2
		neighbors.append(other_node)
	return neighbors


func _get_sharpest_neighbor_pair(map_node: MapLocation) -> Array[MapLocation]:
	var neighbors: Array[MapLocation] = _get_neighbor_nodes(map_node)
	if neighbors.size() < 2:
		return []

	var sharpest_pair: Array[MapLocation] = [neighbors[0], neighbors[1]]
	var min_angle: float = _angle_at_node_degrees(
		map_node.position,
		sharpest_pair[0].position,
		sharpest_pair[1].position
	)

	for first_index in range(neighbors.size()):
		for second_index in range(first_index + 1, neighbors.size()):
			var angle: float = _angle_at_node_degrees(
				map_node.position,
				neighbors[first_index].position,
				neighbors[second_index].position
			)
			if angle >= min_angle:
				continue
			min_angle = angle
			sharpest_pair = [neighbors[first_index], neighbors[second_index]]

	return sharpest_pair


func _get_min_angle_degrees_at_position(node_position: Vector2, map_node: MapLocation) -> float:
	var neighbors: Array[MapLocation] = _get_neighbor_nodes(map_node)
	if neighbors.size() < 2:
		return 180.0

	var min_angle: float = 180.0
	for first_index in range(neighbors.size()):
		for second_index in range(first_index + 1, neighbors.size()):
			var angle: float = _angle_at_node_degrees(
				node_position,
				neighbors[first_index].position,
				neighbors[second_index].position
			)
			min_angle = minf(min_angle, angle)

	return min_angle


func _angle_at_node_degrees(node_position: Vector2, first_neighbor_pos: Vector2, second_neighbor_pos: Vector2) -> float:
	var to_first: Vector2 = (first_neighbor_pos - node_position).normalized()
	var to_second: Vector2 = (second_neighbor_pos - node_position).normalized()
	return rad_to_deg(absf(to_first.angle_to(to_second)))


func _get_angle_improvement_directions(
	map_node: MapLocation,
	first_neighbor: MapLocation,
	second_neighbor: MapLocation
) -> Array[Vector2]:
	var to_first: Vector2 = (first_neighbor.position - map_node.position).normalized()
	var to_second: Vector2 = (second_neighbor.position - map_node.position).normalized()
	var bisector: Vector2 = to_first + to_second

	if bisector.length_squared() < 0.001:
		bisector = Vector2(-to_first.y, to_first.x)
	else:
		bisector = bisector.normalized()

	var perpendicular: Vector2 = Vector2(-bisector.y, bisector.x)
	return [perpendicular, -perpendicular, -bisector, bisector]


func _is_valid_angle_adjustment_position(map_node: MapLocation, candidate_position: Vector2) -> bool:
	for other_node in allNodes:
		if other_node == map_node:
			continue
		var required_distance: float = _get_required_separation(map_node, other_node)
		if candidate_position.distance_to(other_node.position) < required_distance:
			return false
	return true


func _get_required_separation(first_node: MapLocation, second_node: MapLocation) -> float:
	if first_node.type == MapLocation.TYPE.TOWN or second_node.type == MapLocation.TYPE.TOWN:
		return town_min_distance
	if first_node.type == MapLocation.TYPE.VILLAGE or second_node.type == MapLocation.TYPE.VILLAGE:
		return min_distance
	return min_distance


func _clamp_to_map(candidate_position: Vector2) -> Vector2:
	return Vector2(
		clampf(candidate_position.x, margins, mapSize.x - margins),
		clampf(candidate_position.y, margins, mapSize.y - margins)
	)


func _update_node_edges(map_node: MapLocation) -> void:
	for edge in map_node.edges:
		edge.update_line()


# --- Edge crossing cleanup -----------------------------------------------------------------------

func _resolve_edge_crossings() -> void:
	for _pass_index in range(EDGE_CROSSING_MAX_PASSES):
		if _generation_checkpoint():
			return
		var crossing_pair: Array = _find_first_crossing_edge_pair()
		if crossing_pair.is_empty():
			break
		if _try_resolve_crossing_with_villages(crossing_pair[0], crossing_pair[1]):
			continue
		break


func _find_first_crossing_edge_pair() -> Array:
	var edges: Array[MapGraphEdge] = _get_all_edges()
	for first_index in range(edges.size()):
		for second_index in range(first_index + 1, edges.size()):
			var first_edge: MapGraphEdge = edges[first_index]
			var second_edge: MapGraphEdge = edges[second_index]
			if _edges_share_node(first_edge, second_edge):
				continue
			if _edge_pair_crosses(first_edge, second_edge):
				return [first_edge, second_edge]
	return []


func _edges_share_node(first_edge: MapGraphEdge, second_edge: MapGraphEdge) -> bool:
	return (
		first_edge.node1 == second_edge.node1
		or first_edge.node1 == second_edge.node2
		or first_edge.node2 == second_edge.node1
		or first_edge.node2 == second_edge.node2
	)


func _edge_pair_crosses(first_edge: MapGraphEdge, second_edge: MapGraphEdge) -> bool:
	return _segments_intersect(
		first_edge.node1.position,
		first_edge.node2.position,
		second_edge.node1.position,
		second_edge.node2.position
	)


func _count_edge_crossings() -> int:
	var crossing_count: int = 0
	var edges: Array[MapGraphEdge] = _get_all_edges()
	for first_index in range(edges.size()):
		if _generation_checkpoint():
			return crossing_count
		for second_index in range(first_index + 1, edges.size()):
			var first_edge: MapGraphEdge = edges[first_index]
			var second_edge: MapGraphEdge = edges[second_index]
			if _edges_share_node(first_edge, second_edge):
				continue
			if _edge_pair_crosses(first_edge, second_edge):
				crossing_count += 1
	return crossing_count


func _try_resolve_crossing_with_villages(first_edge: MapGraphEdge, second_edge: MapGraphEdge) -> bool:
	var villages: Array[MapLocation] = []
	for village in _get_villages_on_edge(first_edge):
		villages.append(village)
	for village in _get_villages_on_edge(second_edge):
		if villages.has(village):
			continue
		villages.append(village)

	for village in villages:
		if _try_move_village_to_reduce_crossings(village):
			return true

	for village in _get_village_nodes():
		if villages.has(village):
			continue
		if _try_move_village_to_reduce_crossings(village):
			return true

	return false


func _get_villages_on_edge(edge: MapGraphEdge) -> Array[MapLocation]:
	var villages: Array[MapLocation] = []
	for endpoint in [edge.node1, edge.node2]:
		if endpoint.type == MapLocation.TYPE.VILLAGE:
			villages.append(endpoint)
	return villages


func _try_move_village_to_reduce_crossings(village: MapLocation) -> bool:
	if village.type != MapLocation.TYPE.VILLAGE:
		return false

	var original_position: Vector2 = village.position
	var best_position: Vector2 = original_position
	var best_crossing_count: int = _count_edge_crossings()

	for candidate_position in _generate_village_uncross_candidates(village):
		if _generation_checkpoint():
			break
		var clamped_position: Vector2 = _clamp_to_map(candidate_position)
		if not _is_valid_village_move_position(village, clamped_position):
			continue

		village.position = clamped_position
		_update_node_edges(village)
		var crossing_count: int = _count_edge_crossings()
		if crossing_count < best_crossing_count:
			best_crossing_count = crossing_count
			best_position = clamped_position
		if best_crossing_count == 0:
			break

	village.position = best_position
	_update_node_edges(village)
	return not best_position.is_equal_approx(original_position)


func _generate_village_uncross_candidates(village: MapLocation) -> Array[Vector2]:
	var candidates: Array[Vector2] = []
	var neighbors: Array[MapLocation] = _get_neighbor_nodes(village)
	if neighbors.size() != 2:
		return candidates

	var first_neighbor_pos: Vector2 = neighbors[0].position
	var second_neighbor_pos: Vector2 = neighbors[1].position
	var edge_direction: Vector2 = (second_neighbor_pos - first_neighbor_pos).normalized()
	var perpendicular: Vector2 = Vector2(-edge_direction.y, edge_direction.x)
	var along_positions: Array[float] = [0.2, 0.33, 0.5, 0.66, 0.8]

	for along_t in along_positions:
		var on_edge_pos: Vector2 = first_neighbor_pos.lerp(second_neighbor_pos, along_t)
		candidates.append(on_edge_pos)
		for offset_amount in [8.0, 16.0, 24.0, 32.0, 40.0]:
			candidates.append(on_edge_pos + perpendicular * offset_amount)
			candidates.append(on_edge_pos - perpendicular * offset_amount)

	for direction in [perpendicular, -perpendicular, edge_direction, -edge_direction]:
		for step in range(1, SHARP_ANGLE_MAX_STEPS + 1):
			candidates.append(
				village.position + direction * SHARP_ANGLE_MOVE_STEP * float(step)
			)

	return candidates


func _is_valid_village_move_position(village: MapLocation, candidate_position: Vector2) -> bool:
	return _is_far_enough_for_village(
		candidate_position,
		_get_neighbor_nodes(village),
		[]
	)


# --- Graph helpers -------------------------------------------------------------------------------

func _add_map_node(map_node: MapLocation) -> void:
	allNodes.append(map_node)
	add_child(map_node)


func _clear_generated_nodes() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	allNodes.clear()


func _connect_nodes(first_node: MapLocation, second_node: MapLocation, edge_type : MapGraphEdge.EdgeType) -> MapGraphEdge:
	var edge: MapGraphEdge = MapGraphEdge.new(first_node, second_node, edge_type)
	add_child(edge)
	first_node.register_edge(edge)
	second_node.register_edge(edge)
	edge.update_line()
	return edge


func _remove_edge(edge: MapGraphEdge) -> void:
	if edge == null:
		return
	if edge.node1 != null:
		edge.node1.edges.erase(edge)
	if edge.node2 != null:
		edge.node2.edges.erase(edge)
	remove_child(edge)
	edge.free()


func _try_connect_nodes(
	first_node: MapLocation,
	second_node: MapLocation,
	avoid_crossings: bool = true,
	edge_type : MapGraphEdge.EdgeType = MapGraphEdge.EdgeType.LINE
) -> bool:
	if _nodes_are_connected(first_node, second_node):
		return false
	if avoid_crossings and _edge_would_cross_existing(first_node.position, second_node.position):
		return false
	_connect_nodes(first_node, second_node, edge_type)
	return true


func _nodes_are_connected(first_node: MapLocation, second_node: MapLocation) -> bool:
	for edge in first_node.edges:
		if edge.node1 == second_node or edge.node2 == second_node:
			return true
	return false


func _edge_would_cross_existing(from_pos: Vector2, to_pos: Vector2) -> bool:
	for edge in _get_all_edges():
		if _segments_intersect(from_pos, to_pos, edge.node1.position, edge.node2.position):
			return true
	return false


func _segments_intersect(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> bool:
	if a1.is_equal_approx(b1) or a1.is_equal_approx(b2) or a2.is_equal_approx(b1) or a2.is_equal_approx(b2):
		return false
	return Geometry2D.segment_intersects_segment(a1, a2, b1, b2) != null


func _get_all_edges() -> Array[MapGraphEdge]:
	var edges: Array[MapGraphEdge] = []
	for child in get_children():
		if child is MapGraphEdge:
			edges.append(child)
	return edges


func _get_looper_nodes() -> Array[MapLocation]:
	var loopers: Array[MapLocation] = []
	for map_node in allNodes:
		if map_node.type == MapLocation.TYPE.MAP_LOOPER:
			loopers.append(map_node)
	return _sort_nodes_by_x(loopers)


func _get_city_nodes() -> Array[MapLocation]:
	var cities: Array[MapLocation] = []
	for map_node in allNodes:
		if map_node.type == MapLocation.TYPE.CITY:
			cities.append(map_node)
	return cities


func _get_town_nodes() -> Array[MapLocation]:
	var towns: Array[MapLocation] = []
	for map_node in allNodes:
		if map_node.type == MapLocation.TYPE.TOWN:
			towns.append(map_node)
	return towns


func _get_village_nodes() -> Array[MapLocation]:
	var villages: Array[MapLocation] = []
	for map_node in allNodes:
		if map_node.type == MapLocation.TYPE.VILLAGE:
			villages.append(map_node)
	return villages


func _get_main_branch_cities() -> Array[MapLocation]:
	return _sort_nodes_by_x(_get_city_nodes())


func _sort_nodes_by_x(nodes: Array) -> Array[MapLocation]:
	var sorted_nodes: Array[MapLocation] = nodes.duplicate()
	sorted_nodes.sort_custom(func(a: MapLocation, b: MapLocation) -> bool:
		return a.position.x < b.position.x
	)
	return sorted_nodes


func _sort_nodes_by_distance(from_node: MapLocation, nodes: Array[MapLocation]) -> Array[MapLocation]:
	var sorted_nodes: Array[MapLocation] = nodes.duplicate()
	sorted_nodes.sort_custom(func(a: MapLocation, b: MapLocation) -> bool:
		return from_node.position.distance_to(a.position) < from_node.position.distance_to(b.position)
	)
	return sorted_nodes
