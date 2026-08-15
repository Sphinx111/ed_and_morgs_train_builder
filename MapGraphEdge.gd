extends Node2D

class_name MapGraphEdge

enum EdgeType { TRUNK, BRANCH, LINE }

@export var node1: MapLocation
@export var node2: MapLocation
@export var type: EdgeType = EdgeType.TRUNK

var _line: Line2D


func _init(first_node: MapLocation = null, second_node: MapLocation = null, edge_type : EdgeType = EdgeType.LINE) -> void:
	node1 = first_node
	node2 = second_node
	type = edge_type

func _ready() -> void:
	_line = Line2D.new()
	_line.name = "Visual"
	add_child(_line)
	_apply_visual_style()
	update_line()


func update_line() -> void:
	if _line == null or node1 == null or node2 == null:
		return
	_apply_visual_style()
	_line.points = PackedVector2Array([node1.position, node2.position])


func _apply_visual_style() -> void:
	if _line == null:
		return

	match type:
		EdgeType.TRUNK:
			_line.width = 4.0
			_line.default_color = Color(0.85, 0.85, 0.35)
		EdgeType.BRANCH:
			_line.width = 2.5
			_line.default_color = Color(0.4, 0.8, 1.0)
		EdgeType.LINE:
			_line.width = 1.5
			_line.default_color = Color(0.7, 0.9, 0.5)
