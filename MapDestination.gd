extends Node

class_name MapDestination

var distance : float = 0.0
var target : MapLocation = null

func _init(_newDist : float, _newTarget : MapLocation):
	distance = _newDist
	target = _newTarget
