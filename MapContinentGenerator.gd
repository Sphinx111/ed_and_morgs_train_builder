extends Node2D

class_name MapContinentGenerator

@export var DEBUG: bool = true
enum TERRAINS {unassigned, water, land, mountain, river, valley}

class MapBigGrid extends RefCounted:
	var coords: Vector2i
	var tracks: int = 0
	var nodes: int = 0
	var touches_edge: bool = false
	var terrainType: TERRAINS

	func _init(new_coords: Vector2i) -> void:
		coords = new_coords

	func increment_location_count() -> void:
		nodes += 1

	func increment_tracks_count() -> void:
		tracks += 1

var worldSize: Vector2
var granularity: int = 32
var mapGrids: Array = []
var grid_size: Vector2
var _debug_layer: Node2D = null


func _ready() -> void:
	_debug_layer = Node2D.new()
	_debug_layer.name = "GridDebugLayer"
	add_child(_debug_layer)


func create_grids_from_mapGraph(mapGraph: MapGraph) -> void:
	worldSize = mapGraph.mapSize
	grid_size = worldSize / float(granularity)
	_init_map_grids()

	for node: MapLocation in mapGraph.nodes:
		var grid_location: Vector2i = _map_position_to_grid_coord(node.position)
		if _is_valid_grid_coord(grid_location):
			_get_grid_at_coord(grid_location).increment_location_count()

	for edge: MapGraphEdge in mapGraph.edges:
		_mark_grids_for_mapGraphEdge(edge)
		
	generate_terrain(.2)

	_refresh_debug_visuals()


func _init_map_grids() -> void:
	mapGrids.clear()
	for y in range(granularity):
		var row: Array[MapBigGrid] = []
		mapGrids.append(row)
		for x in range(granularity):
			_init_grid_at_coord(x, y)


func _refresh_debug_visuals() -> void:
	if _debug_layer == null:
		return

	for child in _debug_layer.get_children():
		child.queue_free()

	if not DEBUG:
		_debug_layer.visible = false
		return

	_debug_layer.visible = true
	for y in range(granularity):
		for x in range(granularity):
			_add_grid_debug_visual(_get_grid_at_coord(Vector2i(x, y)))


func _add_grid_debug_visual(grid: MapBigGrid) -> void:
	var rect_points := _grid_rect_points(grid.coords.x, grid.coords.y)
	
	var fill := Polygon2D.new()
	fill.name = "Fill_%d_%d" % [grid.coords.x, grid.coords.y]
	fill.polygon = rect_points
	
	if grid.terrainType == TERRAINS.water :
		fill.color = Color(0.0, 0.0, 1.0, 0.22)
	elif grid.terrainType == TERRAINS.land:
		fill.color = Color(0.0, 1.0, 0.0, 0.22)
	else:
		fill.color = Color(0.0, 0.0, 0.0, 0.22)
	_debug_layer.add_child(fill)

	var outline := Line2D.new()
	outline.name = "Outline_%d_%d" % [grid.coords.x, grid.coords.y]
	outline.points = PackedVector2Array([
		rect_points[0],
		rect_points[1],
		rect_points[2],
		rect_points[3],
		rect_points[0],
	])
	outline.width = 1.0
	outline.default_color = Color(1.0, 1.0, 1.0, 0.35)
	_debug_layer.add_child(outline)


func _grid_rect_points(x: int, y: int) -> PackedVector2Array:
	var top_left := Vector2(x, y) * grid_size
	return PackedVector2Array([
		top_left,
		top_left + Vector2(grid_size.x, 0.0),
		top_left + grid_size,
		top_left + Vector2(0.0, grid_size.y),
	])


func _mark_grids_for_mapGraphEdge(edge: MapGraphEdge) -> void:
	if edge.node1 == null or edge.node2 == null:
		return

	for coord: Vector2i in _get_grid_coords_along_line(edge.node1.position, edge.node2.position):
		if _is_valid_grid_coord(coord):
			_get_grid_at_coord(coord).increment_tracks_count()


func _get_grid_coords_along_line(from_position: Vector2, to_position: Vector2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var start_cell := _map_position_to_grid_coord(from_position)
	var end_cell := _map_position_to_grid_coord(to_position)

	if start_cell == end_cell:
		cells.append(start_cell)
		return cells

	var start_grid := Vector2(from_position.x / grid_size.x, from_position.y / grid_size.y)
	var end_grid := Vector2(to_position.x / grid_size.x, to_position.y / grid_size.y)
	var direction := end_grid - start_grid

	var x := start_cell.x
	var y := start_cell.y
	var step_x := 1 if direction.x >= 0.0 else -1
	var step_y := 1 if direction.y >= 0.0 else -1

	var t_delta_x := INF if is_zero_approx(direction.x) else absf(1.0 / direction.x)
	var t_delta_y := INF if is_zero_approx(direction.y) else absf(1.0 / direction.y)

	var x_fraction := start_grid.x - floorf(start_grid.x)
	var y_fraction := start_grid.y - floorf(start_grid.y)
	var t_max_x := (1.0 - x_fraction) * t_delta_x if step_x > 0 else x_fraction * t_delta_x
	var t_max_y := (1.0 - y_fraction) * t_delta_y if step_y > 0 else y_fraction * t_delta_y

	while true:
		cells.append(Vector2i(x, y))
		if x == end_cell.x and y == end_cell.y:
			break
		if t_max_x < t_max_y:
			t_max_x += t_delta_x
			x += step_x
		else:
			t_max_y += t_delta_y
			y += step_y

	return cells


func _is_valid_grid_coord(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < granularity and coord.y >= 0 and coord.y < granularity


func _get_grid_at_coord(coord: Vector2i) -> MapBigGrid:
	return mapGrids[coord.y][coord.x]


func _init_grid_at_coord(x: int, y: int) -> void:
	var grid := MapBigGrid.new(Vector2i(x, y))
	if y == 0 or y == granularity - 1:
		grid.touches_edge = true
	var row: Array[MapBigGrid] = mapGrids[y]
	row.append(grid)


func _map_position_to_grid_coord(map_position: Vector2) -> Vector2i:
	return Vector2i(map_position / grid_size)

func generate_terrain(heat:int=0):
	var gridConcern
	var maxr = granularity-1
	for y in range(granularity):
		for x in range(granularity):
			gridConcern= mapGrids[y][x]
			if gridConcern.nodes > 0 or gridConcern.tracks > 0:
				gridConcern.terrainType = TERRAINS.land
			if x == 0 or x == maxr or y== 0 or y==maxr :
				gridConcern.terrainType = TERRAINS.water
	
	var passes = 2 #generate the map in passes instead of gridbygrid ascending
	for passno in range(passes, 0, -1) : 
		var passheat=heat*(passno/passes)
		for y in range(1,granularity-1):
			if y % passno == 0: 
				for x in range(1,granularity-1):
					if x % passno ==0: #max(1,passno-1)
						gridConcern= mapGrids[y][x]
						if gridConcern.terrainType == TERRAINS.unassigned:
							var landProb : float = terrTypeProb(TERRAINS.land,y,x,passheat)
							var waterProb : float= terrTypeProb(TERRAINS.water,y,x,passheat)
							# TODO: Make better desicsions
							if  landProb >= randf()-heat: #2*waterProb :
								gridConcern.terrainType = TERRAINS.land
							else:
								gridConcern.terrainType = TERRAINS.water
					
# TODO: Write something MUCH better than this
func terrTypeProb(targetType:TERRAINS, y:int, x:int,heat:float=.10) :
	var neighbourTypes=returnNeighborsTerrain(y,x)
	if neighbourTypes.size()>0:
		return (neighbourTypes.filter(func(type): return type == targetType).size()/neighbourTypes.size())
	else:
		return randf()+heat

func returnNeighborsTerrain(y:int, x:int) :
	var neighborTypes : Array = []
	for i in range(y-1,y+1):
		for j in range(x-1,x+1):
			if i!=j: #remove condition to check diagonals
				if i>=0 and j >=0 and i<granularity and j<granularity:
					if mapGrids[i][j].terrainType != TERRAINS.unassigned :
						neighborTypes.append(mapGrids[i][j].terrainType)
	return neighborTypes
			
