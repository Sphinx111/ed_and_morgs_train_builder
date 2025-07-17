extends Node

class_name GenericStorageProvider

var max_storage : Dictionary = {}
var parentModule : ModuleBase = null

func add_storage(type : String, amount : float):
	if max_storage.has(type):
		max_storage[type] = max_storage[type] + amount
	else:
		max_storage[type] = amount

func create_storage(parentTrain : Train):
	for type in max_storage:
		parentTrain.amend_storage(type, max_storage[type])

func remove_storage(parentTrain : Train):
	for type in max_storage:
		parentTrain.amend_storage(type, -max_storage[type])
