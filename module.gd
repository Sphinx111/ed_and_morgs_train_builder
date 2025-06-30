extends Node2D

class_name ModuleBase

var parentCar : TraincarBase = null
var parentTrain : Train = null
var type : String = "empty"
var serves_need : String = "none"
var sequence : int = 0
var efficiency : float = 1.0
var workers_needed : int = 0
var luxury_effect : int = 0

var enabled : bool = true

func _ready():
	parentCar = get_parent()
	parentTrain = parentCar.get_parent()
	position.x = sequence * Globals.module_width

func resource_tick():
	if type == "cabin":
		serves_need = "rest"
		if parentTrain.get_res("clean_water") >= 1:
			parentTrain.add_res("clean_water", -1)
			parentTrain.add_res("black_water", 1)
		pass
	
	if enabled == false:
		return
	
	if type == "kitchen":
		serves_need = "food"
		if parentTrain.get_res("clean_water") >= 1:
			parentTrain.add_res("clean_water", -1)
			parentTrain.add_res("grey_water", 1)
	elif type == "empty":
		pass
	elif type == "clean_water":
		serves_need = "clean_water"
		# Prioritise black water first
		if parentTrain.get_res("black_water") >= 3:
			parentTrain.add_res("black_water", -3)
			parentTrain.add_res("clean_water", 3)
		else:
			var grey_water = parentTrain.get_res("grey_water")
			var amount_to_convert = min(grey_water, 5)
			if amount_to_convert >= 1:
				parentTrain.add_res("grey_water", amount_to_convert)
				parentTrain.add_res("clean_water", amount_to_convert)

# Do anything we need before the module gets deleted
func cleanup():
	pass

func set_sequence(newSequence : int):
	sequence = newSequence
	position.x = sequence * Globals.module_width

func get_service() -> Array:
	var response : Array = [serves_need, 0]
	var resource_available = parentTrain.res[serves_need]
	if resource_available >= 1:
		parentTrain.res[serves_need] -= 1
		response[1] = max(resource_available, 1)
	return response

func set_type(newType : String):
	self.type = newType
	self.serves_need = newType
	if newType == "clean_water":
		$Outline.color = Color.AQUA
	elif newType == "cabin":
		$Outline.color = Color.BROWN
	$Label.text = newType
