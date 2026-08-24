extends RefCounted

class_name TrainCapability

const FEATURE_MAX_EXPEDITIONS := "max_expeditions"


static func apply(feature: String, amount: int) -> void:
	if amount == 0:
		return
	match feature:
		FEATURE_MAX_EXPEDITIONS:
			Globals.max_expeditions += amount
		_:
			push_warning("TrainCapability: unknown feature '%s'" % feature)


static func remove(feature: String, amount: int) -> void:
	if amount == 0:
		return
	match feature:
		FEATURE_MAX_EXPEDITIONS:
			Globals.max_expeditions = maxi(Globals.BASE_MAX_EXPEDITIONS, Globals.max_expeditions - amount)
		_:
			push_warning("TrainCapability: unknown feature '%s'" % feature)
