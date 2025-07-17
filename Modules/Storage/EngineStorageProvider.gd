extends GenericStorageProvider

class_name EngineStorageProvider

func create_storage(parentTrain : Train):
	max_storage = {
		"food1" : 200.0,
		"food2" : 200.0,
		"food3" : 200.0,
		"food4" : 200.0,
		"food5" : 200.0,
		"food6" : 200.0,
		"clean_water" : 200.0,
		"grey_water" : 200.0,
		"black_water" : 200.0,
		"mech_parts" : 200.0,
		"fuel" : 200.0,
		"fertiliser" : 200.0,
		"seeds1" : 200.0,
		"seeds2" : 200.0,
		"seeds3" : 200.0,
		"seeds4" : 200.0,
		"seeds5" : 200.0,
		"seeds6" : 200.0,
		"scrap" : 200.0
	}
	for type in max_storage:
		parentTrain.amend_storage(type, max_storage[type])
