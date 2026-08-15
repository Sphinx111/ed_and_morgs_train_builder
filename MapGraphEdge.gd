extends Node2D

class_name MapGraphEdge

@export var node1: MapLocation
@export var node2: MapLocation

var _line: Line2D


func _init(first_node: MapLocation = null, second_node: MapLocation = null) -> void:
	node1 = first_node
	node2 = second_node


func _ready() -> void:
	_line = Line2D.new()
	_line.name = "Visual"
	_line.width = 3.0
	_line.default_color = Color(0.85, 0.85, 0.35)
	add_child(_line)
	update_line()


func update_line() -> void:
	if _line == null or node1 == null or node2 == null:
		return
	_line.points = PackedVector2Array([node1.position, node2.position])
