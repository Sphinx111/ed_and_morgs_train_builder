@tool
extends Node

class_name MapResourceGenerator

## Resource placement is organised by settlement size - Village/Town/City Resources below,
## each a dictionary of resource type -> ResourceSpec (coverage % and amount, both editable
## as sliders). A location rolls independently for every resource type available to its
## size: on success it gets a single MapResourceContainer at that spec's amount - no
## randomness in the amount itself, only in whether a given location gets it at all.
##
## Main Route Minimums then tops up specific resources along the main route if those rolls
## didn't produce enough of them. Trainyards places at most one train yard on the main route
## (off-route locations can still roll independently), using the same coverage/amount shape.

var mapGraph : MapGraph

@export_group("Village Resources")
## Villages typically end up with just one or two of these (keep coverage percentages low
## overall), but in much larger amounts than towns or cities.
@export var villageResourceSpecs : Dictionary[String, ResourceSpec] = _default_village_specs()

@export_group("Town Resources")
## Towns should end up with roughly half of the available resource types - "pop" is set to
## 100% coverage by default so every town always has some population.
@export var townResourceSpecs : Dictionary[String, ResourceSpec] = _default_town_specs()

@export_group("City Resources")
## Cities should end up with most resource types (high coverage across the board), but in
## smaller amounts than villages.
@export var cityResourceSpecs : Dictionary[String, ResourceSpec] = _default_city_specs()

@export_group("Main Route Minimums")
## Minimum number of main-route locations (cities plus any main-route villages) that must
## end up with each resource type. Topped up deterministically, using each location's own
## settlement-size amount, if the coverage rolls above didn't produce enough. 0 = no
## guarantee - the rolls above decide entirely.
@export var mainRouteMinimums : Dictionary[String, int] = _default_main_route_minimums()

@export_group("Trainyards")
## Same coverage%/amount shape as the resource dictionaries above (amount = train car
## count), but _place_trainyards() caps this so at most one trainyard ends up on the main
## route - locations off the main route can still roll independently with no cap.
@export var villageTrainyardSpec : ResourceSpec = _default_trainyard_spec(0.0, 1.0)
@export var townTrainyardSpec : ResourceSpec = _default_trainyard_spec(15.0, 18.0)
@export var cityTrainyardSpec : ResourceSpec = _default_trainyard_spec(8.0, 1.0)


static func _spec(coverage_pct: float, amount: float, vis: float = 0.3) -> ResourceSpec:
	var s := ResourceSpec.new()
	s.coverage_percent = coverage_pct
	s.amount = amount
	s.visibility = vis
	return s


## Starting point only - tune freely with the sliders. Aims for "most types, small amounts":
## 6 of 7 resource types have some coverage (food1 excluded - cities don't farm).
static func _default_city_specs() -> Dictionary[String, ResourceSpec]:
	return {
		"clean_water": _spec(90.0, 300.0, 0.5),
		"grey_water":  _spec(90.0, 800.0, 0.2),
		"scrap":       _spec(90.0, 750.0, 0.2),
		"oil":         _spec(90.0, 100.0, 0.4),
		"food1":       _spec(90.0,  80.0,  0.1),
		"pop":         _spec(90.0, 60.0,  0.7),
		"mech_parts":  _spec(40.0, 100.0, 0.4),
	}


## Starting point only - aims for "about half the types" (clean_water/scrap/food1/pop = 4 of
## 7), with "pop" always present (100% coverage) so every town has some population.
static func _default_town_specs() -> Dictionary[String, ResourceSpec]:
	return {
		"clean_water": _spec(40.0,  450.0, 0.5),
		"grey_water":  _spec(70.0,   1250.0, 0.2),
		"scrap":       _spec(70.0,  8000.0, 0.2),
		"oil":         _spec(0.0,   150.0, 0.4),
		"food1":       _spec(40.0,  600.0, 0.1),
		"pop":         _spec(90.0, 160.0, 0.7),
		"mech_parts":  _spec(5.0,   150.0, 0.4),
	}


## Starting point only - coverages are deliberately low and sum to ~110%, so a typical
## village ends up with one or two resource types, each in a much larger amount than towns
## or cities get. "pop" is both low-coverage and low-amount - villages have very few people.
static func _default_village_specs() -> Dictionary[String, ResourceSpec]:
	return {
		"clean_water": _spec(25.0, 1200.0,  0.1),
		"grey_water":  _spec(20.0, 2400.0,  0.6),
		"scrap":       _spec(15.0, 1500.0, 1.8),
		"oil":         _spec(10.0, 2500.0, 0.5),
		"food1":       _spec(5.0,  1000.0, 0.1),
		"pop":         _spec(15.0, 40.0,   0.3),
		"mech_parts":  _spec(20.0, 20.0,    0.2),
	}


## Starting point only - "certain resources" the main route should always have some of.
## Everything else defaults to 0 (no guarantee) but is still listed here for easy tuning.
static func _default_main_route_minimums() -> Dictionary[String, int]:
	return {
		"clean_water": 2,
		"food1": 2,
		"scrap": 4,
		"grey_water": 4,
		"oil": 1,
		"pop": 4,
		"mech_parts": 1,
	}


static func _default_trainyard_spec(coverage_pct: float, car_count: float) -> ResourceSpec:
	return _spec(coverage_pct, car_count)


func _specs_for_type(loc_type: MapLocation.TYPE) -> Dictionary[String, ResourceSpec]:
	match loc_type:
		MapLocation.TYPE.VILLAGE:
			return villageResourceSpecs
		MapLocation.TYPE.TOWN:
			return townResourceSpecs
		MapLocation.TYPE.CITY:
			return cityResourceSpecs
	return {}


func _trainyard_spec_for_type(loc_type: MapLocation.TYPE) -> ResourceSpec:
	match loc_type:
		MapLocation.TYPE.VILLAGE:
			return villageTrainyardSpec
		MapLocation.TYPE.TOWN:
			return townTrainyardSpec
		MapLocation.TYPE.CITY:
			return cityTrainyardSpec
	return null


func _rolls_success(coverage_percent: float) -> bool:
	return randf() * 100.0 < coverage_percent


## Generation-time presence check - deliberately ignores MapResourceContainer.discovered
## (has_resource_type()/get_resource_container_of_type() on MapLocation filter by that,
## which is a player-facing "have they found it yet" flag, not what we want here).
func _location_has_resource(location: MapLocation, resource_type: String) -> bool:
	for container in location.resource_containers:
		if container.resource_type == resource_type and not container.is_empty():
			return true
	return false


func add_resources_to_map_graph(_mapGraph : MapGraph) -> void:
	self.mapGraph = _mapGraph
	_place_location_resources()
	_enforce_main_route_minimums()
	_place_trainyards()


## Every location rolls independently, once per resource type available to its settlement
## size. A success places exactly one MapResourceContainer for that resource, at the
## configured amount - no randomness in the amount itself.
func _place_location_resources() -> void:
	for location in mapGraph.nodes:
		var specs: Dictionary[String, ResourceSpec] = _specs_for_type(location.type)
		for resource_type in specs:
			var spec: ResourceSpec = specs[resource_type]
			if spec.amount <= 0.0:
				continue
			if not _rolls_success(spec.coverage_percent):
				continue
			var container := MapResourceContainer.new(resource_type, spec.amount)
			container.visibility = spec.visibility
			location.add_resource_container(container)


## Tops up specific resources along the main route if the rolls above didn't produce enough
## locations carrying them - deterministic, using each location's own settlement-size amount.
func _enforce_main_route_minimums() -> void:
	if mainRouteMinimums.is_empty():
		return

	var main_route: Array[MapLocation] = mapGraph.get_main_route()
	if main_route.is_empty():
		return

	for resource_type in mainRouteMinimums:
		var minimum: int = mainRouteMinimums[resource_type]
		if minimum <= 0:
			continue

		var have_count := 0
		var missing: Array[MapLocation] = []
		for location in main_route:
			if _location_has_resource(location, resource_type):
				have_count += 1
			else:
				missing.append(location)

		var shortfall: int = minimum - have_count
		if shortfall <= 0:
			continue

		for location in missing:
			if shortfall <= 0:
				break
			var spec: ResourceSpec = _specs_for_type(location.type).get(resource_type)
			if spec == null or spec.amount <= 0.0:
				continue # this location's settlement size has no configured amount for this resource
			var container := MapResourceContainer.new(resource_type, spec.amount)
			container.visibility = spec.visibility
			location.add_resource_container(container)
			shortfall -= 1


## Same coverage/amount rules as the resource dictionaries above, but capped so at most one
## trainyard ends up on the main route - off-route locations can still roll independently.
func _place_trainyards() -> void:
	var main_route: Array[MapLocation] = mapGraph.get_main_route()
	var main_route_set: Dictionary = {}
	for location in main_route:
		main_route_set[location] = true

	var main_route_yard_placed := false
	for location in mapGraph.nodes:
		var spec: ResourceSpec = _trainyard_spec_for_type(location.type)
		if spec == null or spec.amount <= 0.0:
			continue

		var on_main_route: bool = main_route_set.has(location)
		if on_main_route and main_route_yard_placed:
			continue # main route cap already satisfied - don't even roll for this one

		if not _rolls_success(spec.coverage_percent):
			continue

		MapResourceLocation.attach_to(location, spec.amount)
		if on_main_route:
			main_route_yard_placed = true
