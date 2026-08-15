@tool
extends Node2D

## Procedural world map generation: a main city spine in pass one, town chains in pass two.
class_name MapGenerator

class TownChain:
	var towns: Array[MapLocation] = []
	var entry_node: MapLocation = null
	var exit_node: MapLocation = null
	var is_above_branch: bool = false


class TownSegmentGroup:
	var above: Array[MapLocation] = []
	var below: Array[MapLocation] = []


@export var numOfCities: int = 6
@export var numOfTowns: int = 6
@export var numOfVillages: int = 12

@export var min_distance: float = 80.0
@export var min_horizontal_distance: float = 100.0
@export var placement_passes: int = 20
@export var connectivity_factor: float = 0.2

var allNodes: Array[MapLocation] = []
var mapSize: Vector2 = Vector2(1024, 724)
var margins: float = 50.0
@export var city_vertical_band: float = 0.4 ## Middle fraction of map height for cities and loopers
@export var town_vertical_band: float = 0.7 ## Middle fraction of map height for towns
var looper_height_helper: float = 0.0


func _ready() -> void:
	_setup_connectivity_slider()
	regenerate_map()


func regenerate_map() -> void:
	var start_time_ms: int = Time.get_ticks_msec()
	looper_height_helper = 0.0
	_clear_generated_nodes()
	first_pass()
	second_pass()
	var elapsed_ms: int = Time.get_ticks_msec() - start_time_ms
	print("MapGenerator.regenerate_map took %d ms" % elapsed_ms)


func _setup_connectivity_slider() -> void:
	var slider: HSlider = get_parent().get_node_or_null("ConnectivitySlider") as HSlider
	if slider == null:
		return
	connectivity_factor = slider.value
	_update_connectivity_label(slider.value)


func _on_connectivity_factor_changed(value: float) -> void:
	connectivity_factor = value
	_update_connectivity_label(value)


func _update_connectivity_label(value: float) -> void:
	var label: Label = get_parent().get_node_or_null("ConnectivityLabel") as Label
	if label != null:
		label.text = "%.2f" % value


# --- Pass one: loopers, cities, and the main spine -----------------------------------------------

func first_pass() -> void:
	allNodes.clear()
	add_map_looper("left")
	for i in range(numOfCities):
		var city_pos: Variant = _pick_map_pos_with_min_city_distance()
		if city_pos == null:
			continue
		_add_map_node(MapLocation.new(MapLocation.CITY, city_pos))
	add_map_looper("right")
	connect_loopers_across_map()


func connect_loopers_across_map() -> void:
	var loopers: Array[MapLocation] = _get_looper_nodes()
	if loopers.size() < 2:
		push_error("MapGenerator: expected two looper nodes")
		return

	var left_looper: MapLocation = loopers[0]
	var right_looper: MapLocation = loopers[loopers.size() - 1]
	var cities: Array[MapLocation] = _get_city_nodes()
	var route: Array[MapLocation] = _build_non_crossing_route(left_looper, cities, right_looper)

	for i in range(route.size() - 1):
		_connect_nodes(route[i], route[i + 1])


# --- Pass two: town placement, x-ordered chains, optional cross-links ----------------------------

func second_pass() -> void:
	var towns: Array[MapLocation] = _place_all_towns()
	if towns.is_empty():
		return

	var main_route: Array[MapLocation] = _get_main_branch_route()
	if main_route.size() < 2:
		return

	var cities: Array[MapLocation] = _get_main_branch_cities()
	var chains: Array[TownChain] = _build_town_chains(towns, main_route)

	for chain in chains:
		_connect_town_chain(chain)

	_apply_connectivity_factor(chains, cities)


func _place_all_towns() -> Array[MapLocation]:
	var towns: Array[MapLocation] = []
	for i in range(numOfTowns):
		var town_pos: Variant = _pick_map_pos_with_min_town_distance()
		if town_pos == null:
			continue
		var town: MapLocation = MapLocation.new(MapLocation.TOWN, town_pos)
		_add_map_node(town)
		towns.append(town)
	return towns


func _build_town_chains(towns: Array[MapLocation], main_route: Array[MapLocation]) -> Array[TownChain]:
	var chains: Array[TownChain] = []
	if towns.is_empty() or main_route.size() < 2:
		return chains

	var segment_groups: Array[TownSegmentGroup] = []
	for i in range(main_route.size() - 1):
		segment_groups.append(TownSegmentGroup.new())

	for town in towns:
		var segment_index: int = _get_route_segment_index_at_x(main_route, town.position.x)
		var branch_y: float = _get_branch_y_at_x(main_route, segment_index, town.position.x)
		if town.position.y < branch_y:
			segment_groups[segment_index].above.append(town)
		else:
			segment_groups[segment_index].below.append(town)

	for segment_index in range(segment_groups.size()):
		var group: TownSegmentGroup = segment_groups[segment_index]
		var entry_node: MapLocation = _resolve_town_anchor_to_city(main_route[segment_index])
		var exit_node: MapLocation = _resolve_town_anchor_to_city(main_route[segment_index + 1])

		if entry_node == null or exit_node == null:
			continue

		if not group.above.is_empty():
			chains.append(_make_town_chain(group.above, entry_node, exit_node, true))
		if not group.below.is_empty():
			chains.append(_make_town_chain(group.below, entry_node, exit_node, false))

	return chains


func _make_town_chain(
	towns: Array[MapLocation],
	entry_node: MapLocation,
	exit_node: MapLocation,
	is_above_branch: bool
) -> TownChain:
	var chain := TownChain.new()
	chain.towns = _sort_nodes_by_x(towns)
	chain.entry_node = entry_node
	chain.exit_node = exit_node
	chain.is_above_branch = is_above_branch
	return chain


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


func _resolve_town_anchor_to_city(node: MapLocation) -> MapLocation:
	if node == null:
		return null
	if node.type == MapLocation.CITY:
		return node

	var cities: Array[MapLocation] = _get_city_nodes()
	if cities.is_empty():
		return null

	return _sort_nodes_by_distance(node, cities)[0]


func _connect_town_chain(chain: TownChain) -> void:
	if chain.towns.is_empty():
		return

	for i in range(chain.towns.size() - 1):
		_connect_with_crossing_fallback(chain.towns[i], chain.towns[i + 1])

	if chain.entry_node != null:
		_connect_with_crossing_fallback(chain.entry_node, chain.towns[0])

	if chain.exit_node != null:
		var last_town: MapLocation = chain.towns[chain.towns.size() - 1]
		if chain.exit_node != chain.entry_node or last_town == chain.towns[0]:
			_connect_with_crossing_fallback(last_town, chain.exit_node)


func _connect_with_crossing_fallback(first_node: MapLocation, second_node: MapLocation) -> void:
	if _try_connect_nodes(first_node, second_node):
		return
	_try_connect_nodes(first_node, second_node, false)


func _apply_connectivity_factor(chains: Array[TownChain], cities: Array[MapLocation]) -> void:
	if connectivity_factor <= 0.0:
		return

	for chain_index in range(chains.size()):
		for town in chains[chain_index].towns:
			if randf() > connectivity_factor:
				continue
			var target: MapLocation = _pick_connectivity_extra_target(
				town,
				chain_index,
				chains,
				cities
			)
			if target != null:
				_try_connect_nodes(town, target)


func _pick_connectivity_extra_target(
	town: MapLocation,
	own_chain_index: int,
	chains: Array[TownChain],
	cities: Array[MapLocation]
) -> MapLocation:
	var candidates: Array[MapLocation] = []
	var own_chain: TownChain = chains[own_chain_index]

	for chain_index in range(chains.size()):
		if chain_index == own_chain_index:
			continue
		if chains[chain_index].is_above_branch != own_chain.is_above_branch:
			continue
		for other_town in chains[chain_index].towns:
			if not _nodes_are_connected(town, other_town):
				candidates.append(other_town)

	for city in cities:
		if not _nodes_are_connected(town, city):
			candidates.append(city)

	if candidates.is_empty():
		return null

	return _sort_nodes_by_distance(town, candidates)[0]


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


func _pick_map_pos_with_min_village_distance() -> Variant:
	for _attempt in range(placement_passes):
		var candidate: Vector2 = pick_random_map_pos()
		if _is_far_enough_for_village(candidate):
			return candidate
	return null


func _is_far_enough_from_cities(pos: Vector2) -> bool:
	for map_node in allNodes:
		if map_node.type != MapLocation.CITY:
			continue
		if abs(pos.x - map_node.position.x) < min_horizontal_distance:
			return false
	return true


func _is_far_enough_for_town(pos: Vector2) -> bool:
	for map_node in allNodes:
		if map_node.type != MapLocation.CITY and map_node.type != MapLocation.TOWN:
			continue
		if pos.distance_to(map_node.position) < min_distance:
			return false
	return true


func _is_far_enough_for_village(pos: Vector2) -> bool:
	for map_node in allNodes:
		if (
			map_node.type != MapLocation.CITY
			and map_node.type != MapLocation.TOWN
			and map_node.type != MapLocation.VILLAGE
		):
			continue
		if pos.distance_to(map_node.position) < min_distance:
			return false
	return true


func add_map_looper(edge: String) -> void:
	if looper_height_helper == 0.0:
		var y_range: Vector2 = _get_vertical_y_range_from_band(city_vertical_band)
		looper_height_helper = randf_range(y_range.x, y_range.y)
	var pos: Vector2 = Vector2(0.0, looper_height_helper)
	if edge == "right":
		pos.x = mapSize.x
	_add_map_node(MapLocation.new(MapLocation.MAP_LOOPER, pos))


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


# --- Graph helpers -------------------------------------------------------------------------------

func _add_map_node(map_node: MapLocation) -> void:
	allNodes.append(map_node)
	add_child(map_node)


func _clear_generated_nodes() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	allNodes.clear()


func _connect_nodes(first_node: MapLocation, second_node: MapLocation) -> MapGraphEdge:
	var edge: MapGraphEdge = MapGraphEdge.new(first_node, second_node)
	add_child(edge)
	first_node.register_edge(edge)
	second_node.register_edge(edge)
	edge.update_line()
	return edge


func _try_connect_nodes(
	first_node: MapLocation,
	second_node: MapLocation,
	avoid_crossings: bool = true
) -> bool:
	if _nodes_are_connected(first_node, second_node):
		return false
	if avoid_crossings and _edge_would_cross_existing(first_node.position, second_node.position):
		return false
	_connect_nodes(first_node, second_node)
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
		if map_node.type == MapLocation.MAP_LOOPER:
			loopers.append(map_node)
	return _sort_nodes_by_x(loopers)


func _get_city_nodes() -> Array[MapLocation]:
	var cities: Array[MapLocation] = []
	for map_node in allNodes:
		if map_node.type == MapLocation.CITY:
			cities.append(map_node)
	return cities


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
