extends RefCounted

## Data object for a generated map graph.
## Holds the same MapLocation and MapGraphEdge instances produced by MapGraphGenerator,
## so node.edges and edge.node1 / edge.node2 remain linked.
class_name MapGraph

var nodes: Array[MapLocation] = []
var edges: Array[MapGraphEdge] = []
var allCities: Array[MapLocation] = []
var allTowns: Array[MapLocation] = []
var allVillages: Array[MapLocation] = []
var loopers: Array[MapLocation] = []
## Ordered spine from left looper to right looper: cities that connect the loopers,
## plus villages later inserted on those trunk edges. Null until get_main_route().
var mainRoute = null


static func from_nodes(graph_nodes: Array[MapLocation]) -> MapGraph:
	var graph := MapGraph.new()
	graph.nodes.assign(graph_nodes)
	graph.edges.assign(_collect_unique_edges(graph_nodes))
	graph._populate_typed_node_lists()
	return graph


func get_main_route() -> Array[MapLocation]:
	if mainRoute != null:
		return mainRoute
	if loopers.is_empty() and not nodes.is_empty():
		_populate_typed_node_lists()
	_populate_main_route()
	return mainRoute


func _populate_typed_node_lists() -> void:
	allCities.clear()
	allTowns.clear()
	allVillages.clear()
	loopers.clear()
	for map_node in nodes:
		match map_node.type:
			MapLocation.TYPE.CITY:
				allCities.append(map_node)
			MapLocation.TYPE.TOWN:
				allTowns.append(map_node)
			MapLocation.TYPE.VILLAGE:
				allVillages.append(map_node)
			MapLocation.TYPE.MAP_LOOPER:
				loopers.append(map_node)
	loopers.sort_custom(func(a: MapLocation, b: MapLocation) -> bool:
		return a.position.x < b.position.x
	)


func _populate_main_route() -> void:
	var route: Array[MapLocation] = []
	if loopers.size() < 2:
		mainRoute = route
		return

	var start_node: MapLocation = loopers[0]
	var end_node: MapLocation = loopers[loopers.size() - 1]
	var visited: Dictionary = {}

	route.append(start_node)
	visited[start_node] = true

	var previous_node: MapLocation = null
	var current_node: MapLocation = start_node
	while current_node != end_node:
		var next_node: MapLocation = _get_next_trunk_neighbor(current_node, previous_node, visited)
		if next_node == null:
			break
		route.append(next_node)
		visited[next_node] = true
		previous_node = current_node
		current_node = next_node

	mainRoute = route


func _get_next_trunk_neighbor(
	current_node: MapLocation,
	previous_node: MapLocation,
	visited: Dictionary
) -> MapLocation:
	for edge in current_node.edges:
		if edge.type != MapGraphEdge.EdgeType.TRUNK:
			continue
		var other_node: MapLocation = edge.node1
		if other_node == current_node:
			other_node = edge.node2
		if other_node == previous_node or visited.has(other_node):
			continue
		return other_node
	return null


static func _collect_unique_edges(graph_nodes: Array[MapLocation]) -> Array[MapGraphEdge]:
	var unique_edges: Array[MapGraphEdge] = []
	for map_node in graph_nodes:
		for edge in map_node.edges:
			if not unique_edges.has(edge):
				unique_edges.append(edge)
	return unique_edges
