extends GenericStorageProvider

class_name EngineStorageProvider

func create_storage(parentTrain : Train):
	max_storage = {
		"food1" : 100.0,
		"food2" : 100.0,
		"food3" : 100.0,
		"food4" : 100.0,
		"food5" : 100.0,
		"food6" : 100.0,
		"clean_water" : 200.0,
		"grey_water" : 200.0,
		"black_water" : 200.0,
		"mech_parts" : 200.0,
		"fuel" : 200.0,
		"fertiliser" : 200.0,
		"scrap" : 200.0,
		"oil" : 100.00
	}
	for type in max_storage:
		parentTrain.amend_storage(type, max_storage[type])
