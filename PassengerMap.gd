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

func modify_several_needs_maps(needsArray : Array[String], trainPos : Array[int], newState : int):
	for need in needsArray:
		update_map_segment(needsLocations, need, needsMaps, trainPos, newState)

func update_map_segment(locationsMap, mapType : String, outputDict, position2d : Array, newState : int):
	# Placeholder - Just recalculate the entire map until this function works properly
	#calc_direction_weights(locationsMap, mapType, outputDict)
	
	# Update the directions map, limited to the slice of array affected by the changed position
	var changed_index = Helpers.coords_to_index(position2d)
	var isLeftmost : bool = false
	var isRightmost : bool = false
	var outputMap : Array[int] = outputDict[mapType]

	# Identify whether this module is the only one, or first/last on the train
	var findRight : int = find_next_existing(outputMap, 1, changed_index)
	var findLeft : int = find_next_existing(outputMap, -1, changed_index)
	
	if findRight == -1:
		isRightmost = true
	if findLeft == -1:
		isLeftmost = true
	
	# Update the location map for this one position only
	locationsMap[mapType][position2d[0]][position2d[1]] = newState
	
	# REMOVING a module from map
	if newState == Globals.CUSTOMERS_FULL or newState == Globals.MODULE_REMOVED:
		# If this was the only module of its kind
		if isLeftmost and isRightmost:
			outputDict[mapType].fill(9999)
			return
		
		var i : int = 0
		
		# If the module is the leftmost, updating is easy
		# Start from start of map, and update forwards until you find a pointer to the next module
		if isLeftmost:
			var nextVal = 0 - findRight
			while i < findRight:
				# If we reach an existing pointer to next module, stop updating
				if i > changed_index and outputMap[i] > 0:
					return
				outputDict[mapType][i] = nextVal
				nextVal -= 1
				i += 1
			return
		
		# Similarly, if module is rightmost, updating is easy
		# Start at the end of map, and update backwards until you find a pointer to the previous module
		if isRightmost:
			i = outputMap.size()-1
			var nextVal = findLeft - i
			while i > findLeft:
				if i < changed_index and outputMap[i] < 0:
					return
				outputDict[mapType][i] = nextVal
				nextVal += 1
				i -= 1
			return
		
		# If we get to this point, we have removed a module that is between two other modules
		# findLeft holds the position of the module to the left
		# findRight holds the position of the module to the right
		# We're just going to iterate through positions between left and right, updating as we go
		i = findLeft + 1
		var nextVal = -1
		var midPoint = findLeft + ((findRight - findLeft) / 2)
		while i < findRight:
			if i == midPoint:
				nextVal = findRight - midPoint
			outputDict[mapType][i] = nextVal
			i += 1
			nextVal -= 1
	
	# ADDING a module in - for now just rebuild the whole map
	if newState == Globals.CUSTOMERS_HAS_SPACE or newState == Globals.MODULE_ADDED:
		# If this is the only module, just do a rebuild, re-use existing code
		if isLeftmost and isRightmost:
			for i in range(outputDict[mapType].size()):
				outputDict[mapType][i] = changed_index - i
			return
		
		var startWriteAt : int = 0
		var endWriteAt : int = 0
		var startValue : int = 0
		
		# If we are inserting a new module on the furthest left
		if isLeftmost:
			startWriteAt = 0
			endWriteAt = changed_index + ((findRight - changed_index) / 2)      # midpoint between this and next existing module
			startValue = changed_index
		# If we are inserting a module on the furthest right
		elif isRightmost:
			startWriteAt = findLeft + ((changed_index - findLeft) / 2) + 1          # midpoint between last existing module and this
			endWriteAt = outputMap.size()
			startValue = changed_index - startWriteAt
		# If the module being inserted is in the middle of two others, recalculate from midpointLeft to midpointRight
		else:
			startWriteAt = findLeft + ((changed_index - findLeft) / 2) + 1         # midpoint between last existing module and this
			endWriteAt = changed_index + ((findRight - changed_index) / 2)      # midpoint between this and next existing module
			startValue = changed_index - startWriteAt

		var i : int = startWriteAt
		var nextVal : int = startValue
		while i < endWriteAt:               # iterate from last midpoint to next midpoint
				outputDict[mapType][i] = nextVal             # Save new value to map
				i += 1                                       # increment variables
				nextVal -= 1
		
		pass

## Find the next instance of module in map array
func find_next_existing(map_to_search: Array, direction : int, start_index : int) -> int:
	var i : int = start_index + direction
	while i > 0 and i < map_to_search.size():
		if map_to_search[i] == 0:
			return i
		i += direction
	return -1


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
