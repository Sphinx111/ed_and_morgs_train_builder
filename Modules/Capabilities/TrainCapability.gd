extends RefCounted

class_name TrainCapability

const FEATURE_MAX_EXPEDITIONS := "max_expeditions"
const FEATURE_ANTENNA_COUNT := "antenna_count"
const FEATURE_KITE_SAIL_COUNT := "kite_sail_count"


static func apply(feature: String, amount: int) -> void:
	if amount == 0:
		return
	match feature:
		FEATURE_MAX_EXPEDITIONS:
			Globals.max_expeditions += amount
		FEATURE_ANTENNA_COUNT:
			Globals.antenna_count += amount
		FEATURE_KITE_SAIL_COUNT:
			Globals.kite_sail_count += amount
		_:
			push_warning("TrainCapability: unknown feature '%s'" % feature)


static func remove(feature: String, amount: int) -> void:
	if amount == 0:
		return
	match feature:
		FEATURE_MAX_EXPEDITIONS:
			Globals.max_expeditions = maxi(Globals.BASE_MAX_EXPEDITIONS, Globals.max_expeditions - amount)
		FEATURE_ANTENNA_COUNT:
			Globals.antenna_count = maxi(0, Globals.antenna_count - amount)
		FEATURE_KITE_SAIL_COUNT:
			Globals.kite_sail_count = maxi(0, Globals.kite_sail_count - amount)
		_:
			push_warning("TrainCapability: unknown feature '%s'" % feature)
