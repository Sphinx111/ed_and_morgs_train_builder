extends Node2D

## This represents a 'node' on the map where tracks should connect to
class_name MapLocation

const CITY: int = 0
const TOWN: int = 1
const VILLAGE: int = 2
const MAP_LOOPER: int = 3

const VISUAL_RADIUS: float = 8.0

var type: int = 0
var edges: Array[MapGraphEdge] = []


func _init(new_type: int, map_position: Vector2 = Vector2.ZERO) -> void:
	type = new_type
	position = map_position
	_setup_visual()


func register_edge(edge: MapGraphEdge) -> void:
	if not edges.has(edge):
		edges.append(edge)


func _setup_visual() -> void:
	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.color = _get_type_color()
	visual.polygon = _make_circle_polygon(VISUAL_RADIUS, 16)
	add_child(visual)


func _get_type_color() -> Color:
	match type:
		MapLocation.CITY:
			return Color(1.0, 0.85, 0.2)
		MapLocation.TOWN:
			return Color(0.4, 0.8, 1.0)
		MapLocation.VILLAGE:
			return Color(0.7, 0.9, 0.5)
		MapLocation.MAP_LOOPER:
			return Color(1.0, 0.3, 0.3)
		_:
			return Color.WHITE


func _make_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
