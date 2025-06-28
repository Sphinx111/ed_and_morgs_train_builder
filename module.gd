extends Node2D

class_name ModuleBase

var parentCar : TraincarBase = null
var parentTrain : Train = null
var type : String = "empty"
var efficiency : float = 1.0
var workers_needed : int = 0
var luxury_effect : int = 0

var enabled : bool = true

func ready():
	parentCar = get_parent()
	parentTrain = parentCar.get_parent()

func resource_tick():
	if type == "cabin":
		if parentTrain.get_res("clean_water") >= 1:
			parentTrain.add_res("clean_water", -1)
			parentTrain.add_res("black_water", 1)
		pass
	
	if enabled == false:
		return
	
	if type == "kitchen":
		if parentTrain.get_res("clean_water") >= 1:
			parentTrain.add_res("clean_water", -1)
			parentTrain.add_res("grey_water", 1)
	elif type == "empty":
		pass
	elif type == "clean_water":
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

func set_type(newType : String):
	self.type = newType
	$Outline.modulate = Color.AQUA
	$Label.text = newType
