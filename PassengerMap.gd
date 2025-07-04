extends Node

class_name PassengerMap

var train = null

var needsLocations = {
	"thirst"    : [[]],
	"hunger"    : [[]],
	"rest"      : [[]],
}

# 1d location map
var needsMaps = {
	"thirst"    : [],
	"hunger"    : [],
	"rest"      : []
}

var workLocations = {
	"any" : [[]]
}

# 1d location array
var workMaps = {
	"any" : []
}

func set_train(newTrain : Train):
	train = newTrain

func init_maps():
	for key in needsLocations.keys():
		needsLocations[key] = train.get_location_map_for_type(key)
		calc_direction_weights(needsLocations, key, needsMaps)
	for key in workLocations.keys():
		workLocations[key] = train.get_work_location_map_for_type(key)
		calc_direction_weights(workLocations, key, workMaps)

func update_single_type_map(needs_type_to_update):
	needsLocations[needs_type_to_update] = train.get_location_map_for_type(needs_type_to_update)
	calc_direction_weights(needsLocations, needs_type_to_update, needsMaps)

func update_single_work_type_map(work_type_to_update):
	workLocations[work_type_to_update] = train.get_work_location_map_for_type(work_type_to_update)
	calc_direction_weights(workLocations, work_type_to_update, workMaps)

func calc_direction_weights(locationsMap : Dictionary, mapType : String, outputDict : Dictionary):
	# Reads the type map, and builds a vector diagram for each position on the train
	# telling passengers whether to go left or right, to get to a module of the desired type
	var flat_map : Array = []
	
	# Start by converting 2D array into a 1D array
	for carriage in locationsMap[mapType]:
		for module in carriage:
			flat_map.append(module)
	
	var directionsMap : Array[int] = []
	directionsMap.resize(flat_map.size()) 
	directionsMap.fill(9999) # "9999" is our "uninitialized" value for directions Map
	var lastFoundPos = -1
	var scanner_position = 0
	
	while scanner_position < flat_map.size():
		# Search for the first module of this type:
		if lastFoundPos == -1:
			# Found module for the first time, set scanner head back to 0
			if flat_map[scanner_position] == 1:
				lastFoundPos = scanner_position
				#print_debug("found type at position: " + String.num_int64(scanner_position))
				scanner_position = 0
			# keep looking for first instance of module
			else:
				scanner_position += 1
		else:
			# Get distance between current position and currently tracked module:
			var distance = lastFoundPos - scanner_position
			var currentDistValue = directionsMap[scanner_position]

			# Check whether we have encounted a new module of the same type... 
			if scanner_position != lastFoundPos and flat_map[scanner_position] == 1:
				# Update tracked module, and send scanner position back halfway to the previous module
				var distBetweenModules = scanner_position - lastFoundPos
				lastFoundPos = scanner_position
				scanner_position = lastFoundPos - floor(distBetweenModules / 2)
			#  We keep adding distances to last tracked module
			else:
				if currentDistValue == 9999 or ( abs(distance) < abs(currentDistValue)):
					directionsMap[scanner_position] = distance
				scanner_position += 1
	
	# Finally, save the directionsMap back
	outputDict[mapType] = directionsMap.duplicate()
	pass

func get_direction_from_to(position : Array[int], type : String, mapToUse: String) -> int:
	var index = -1
	index = position[0] * 4 + position[1]
	
	if mapToUse == "need":
		if needsMaps.has(type):
			return needsMaps[type][index]
	elif mapToUse == "work":
		if workMaps.has(type):
			return workMaps[type][index]
	return 0
