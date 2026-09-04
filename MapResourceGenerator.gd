extends Resource

class_name MapResourceGenerator

## Helper class to define resources available to different setups
class ResourceSpec:
	var resource_type : String
	var total_to_place : float = 0.0
	var avg_amount_per_spot : float = 0.0
	var min_per_location : float = 0.0
	var min_location_size : MapLocation.TYPE
	var force_location_size : bool # If true, this batch of resources must be placed only in cities that match min_location_size exactly
	var visibility : float = 0.0   # Weight when choosing which deposit scavenge reveals
	var rarity : float = 0.0       # Chance to skip placing at a location: 0.0 = always, 1.0 = never
	
	func _init(
		t : String,
		ttp : float,
		avg_spot : float,
		mnpl : float,
		mls : MapLocation.TYPE,
		fls : bool = false,
		vis : float = 0.0,
		r : float = 0.0
	):
		resource_type = t
		total_to_place = ttp
		avg_amount_per_spot = avg_spot
		min_per_location = mnpl
		min_location_size = mls
		force_location_size = fls
		visibility = vis
		rarity = r

var mapGraph : MapGraph
var firstPassTotals : Array[ResourceSpec] = [
	ResourceSpec.new("clean_water", 550.0,   55.0, 50.0, MapLocation.TYPE.VILLAGE, false, 0.9, 0.3),
	ResourceSpec.new("clean_water", 950.0,   55.0, 50.0, MapLocation.TYPE.VILLAGE, false, 0.7, 0.4),
	ResourceSpec.new("grey_water",  800.0,   125.0, 50.0, MapLocation.TYPE.VILLAGE, false,  0.2, 0.1),
	ResourceSpec.new("grey_water",  1200.0,  225.0, 50.0, MapLocation.TYPE.VILLAGE, false,  0.4, 0.4),
	ResourceSpec.new("scrap",       5100.0,  250.0, 0.0, MapLocation.TYPE.TOWN,    false,  0.2, 0.1),
	ResourceSpec.new("oil",         220.0,   80.0,  0.0, MapLocation.TYPE.CITY,    true,   0.6, 0.0),
	ResourceSpec.new("oil",         800.0,   120.0,  0.0, MapLocation.TYPE.VILLAGE, true,   0.4, 0.1),
	ResourceSpec.new("food1",       420.0,   100.0,  0.0, MapLocation.TYPE.TOWN,    false,  0.1, 0.4),
	ResourceSpec.new("pop",         125.0,   8.0,   5.0, MapLocation.TYPE.VILLAGE, false,  1.5, 0.1),
	ResourceSpec.new("mech_parts",  200.0,   30.0,  10.0, MapLocation.TYPE.CITY,    false,  0.4, 0.8)
]

var secondPassTotals: Array[ResourceSpec] = [
	ResourceSpec.new("clean_water", 2000.0,  100.0,  0.0, MapLocation.TYPE.VILLAGE,  false,  0.5, 0.5),
	ResourceSpec.new("grey_water",  8000.0,  300.0, 0.0, MapLocation.TYPE.VILLAGE,  false,  0.3, 0.5),
	ResourceSpec.new("scrap",       40000.0, 800.0, 0.0, MapLocation.TYPE.TOWN,     false,  0.2, 0.5),
	ResourceSpec.new("oil",         500.0,   120.0,  0.0, MapLocation.TYPE.CITY,     true,   0.6, 0.5),
	ResourceSpec.new("oil",         4000.0,  420.0, 0.0, MapLocation.TYPE.VILLAGE,  true,   0.4, 0.5),
	ResourceSpec.new("food1",       8200.0,  400.0, 0.0, MapLocation.TYPE.TOWN,     false,  0.1, 0.5),
	ResourceSpec.new("pop",         1000.0,   25.0,  0.0, MapLocation.TYPE.VILLAGE,  false,  0.2, 0.5),
	ResourceSpec.new("mech_parts",  500.0,   30.0,  0.0, MapLocation.TYPE.CITY,     false,  0.7, 0.5)
]

var variability : float = 0.8 # Proportion up or down resources vary per city

func _spot_amount(resourceSpec: ResourceSpec) -> float:
	if resourceSpec.avg_amount_per_spot <= 0.0:
		return 0.0
	return resourceSpec.avg_amount_per_spot * randf_range(1.0 - variability, 1.0 + variability)

func _add_resource_spots_at_location(location: MapLocation, resourceSpec: ResourceSpec, location_budget: float) -> float:
	if location_budget <= 0.0:
		return 0.0

	var placed := 0.0
	while placed < location_budget:
		var remaining := location_budget - placed
		var spot_amount : float
		if resourceSpec.avg_amount_per_spot > 0.0:
			spot_amount = minf(_spot_amount(resourceSpec), remaining)
		else:
			spot_amount = remaining
		if spot_amount <= 0.0:
			break

		var resource_container := MapResourceContainer.new(
			resourceSpec.resource_type,
			spot_amount
		)
		resource_container.visibility = resourceSpec.visibility
		location.add_resource_container(resource_container)
		placed += spot_amount
	return placed

func _should_skip_location_for_rarity(resourceSpec: ResourceSpec) -> bool:
	return randf() < resourceSpec.rarity

func add_resources_to_map_graph(_mapGraph : MapGraph) -> void:
	self.mapGraph = _mapGraph
	cities_first_pass()
	nodes_second_pass()
	place_train_yards()


func place_train_yards() -> void:
	var towns: Array[MapLocation] = []
	for location in mapGraph.nodes:
		if location.type == MapLocation.TYPE.TOWN:
			towns.append(location)
	if towns.is_empty():
		return

	towns.shuffle()
	var yards_to_place: int = mini(3, towns.size())
	for index in range(yards_to_place):
		var car_count: float = maxf(1.0, roundi(randf_range(1.0, 3.0)))
		MapResourceLocation.attach_to(towns[index], car_count)

func cities_first_pass():
	var mainRoute : Array[MapLocation] = mapGraph.get_main_route()
	for resourceSpec in firstPassTotals:
		var remainingLocations : int = mainRoute.size()
		if resourceSpec.force_location_size == true:
			continue	## Come back to forced location size items later
		
		var total_remaining : float = resourceSpec.total_to_place
		for location in mainRoute:
			# Skip locations that are wrong size for this ResourceSpec
			if (location.type < resourceSpec.min_location_size or 
				(resourceSpec.force_location_size and location.type != resourceSpec.min_location_size)):
				remainingLocations -= 1
				continue
			
			if _should_skip_location_for_rarity(resourceSpec):
				remainingLocations -= 1
				continue
			
			var amount_to_place : float = total_remaining / float(remainingLocations) * randf_range(1 - variability, 1 + variability)
			amount_to_place = maxf(amount_to_place, resourceSpec.min_per_location)
			amount_to_place = minf(amount_to_place, total_remaining)
			var placed_amount := _add_resource_spots_at_location(location, resourceSpec, amount_to_place)
			remainingLocations -= 1
			total_remaining -= placed_amount


func nodes_second_pass() -> void:
	var unusedLocations: Array[MapLocation] = []
	for location in mapGraph.nodes:
		if location.resource_containers.is_empty():
			unusedLocations.append(location)

	for resourceSpec in secondPassTotals:
		var eligibleLocations: Array[MapLocation] = []
		for location in unusedLocations:
			if location.type < resourceSpec.min_location_size:
				continue
			if resourceSpec.force_location_size and location.type != resourceSpec.min_location_size:
				continue
			eligibleLocations.append(location)

		var remainingLocations: int = eligibleLocations.size()
		if remainingLocations <= 0:
			continue

		var total_remaining: float = resourceSpec.total_to_place
		for location in eligibleLocations:
			if remainingLocations <= 0 or total_remaining <= 0.0:
				break

			if _should_skip_location_for_rarity(resourceSpec):
				remainingLocations -= 1
				continue

			var share: float = total_remaining / float(remainingLocations) * randf_range(1 - variability, 1 + variability)
			var amount_to_place: float = share
			if resourceSpec.min_per_location > 0.0:
				amount_to_place = maxf(share, resourceSpec.min_per_location)
			amount_to_place = minf(amount_to_place, total_remaining)

			var placed_amount := _add_resource_spots_at_location(location, resourceSpec, amount_to_place)
			remainingLocations -= 1
			total_remaining -= placed_amount
