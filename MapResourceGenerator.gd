extends Resource

class_name MapResourceGenerator

## Helper class to define resources available to different setups
class ResourceSpec:
	var resource_type : String
	var total_to_place : float = 0.0
	var min_per_location : float = 0.0
	var min_location_size : MapLocation.TYPE
	var force_location_size : bool # If true, this batch of resources must be placed only in cities that match min_location_size exactly
	var rarity : float             # Chance that a location contains none of this resource at all
	
	func _init(t : String, ttp : float, mnpl : float, mls : MapLocation.TYPE, fls : bool = false, r : float = 0.0):
		resource_type = t
		total_to_place = ttp
		min_per_location = mnpl
		min_location_size = mls
		force_location_size = fls
		rarity = r

var mapGraph : MapGraph
var firstPassTotals : Array[ResourceSpec] = [
	ResourceSpec.new("clean_water", 250.0,   20.0, MapLocation.TYPE.VILLAGE, false, 0.5),
	ResourceSpec.new("grey_water",  400.0,   50.0, MapLocation.TYPE.VILLAGE, false,  0.3),
	ResourceSpec.new("scrap",       2100.0,  0.0,  MapLocation.TYPE.TOWN,    false,  0.2),
	ResourceSpec.new("oil",         220.0,   0.0,  MapLocation.TYPE.CITY,    true,   0.6),
	ResourceSpec.new("oil",         800.0,   0.0,  MapLocation.TYPE.VILLAGE, true,   0.4),
	ResourceSpec.new("food1",       420.0,   0.0,  MapLocation.TYPE.TOWN,    false,  0.1),
	ResourceSpec.new("pop",         125.0,   5.0,  MapLocation.TYPE.VILLAGE, false,  0.0),
	ResourceSpec.new("mech_parts",  200.0,   10.0, MapLocation.TYPE.CITY,    false,  0.4)
]

var secondPassTotals: Array[ResourceSpec] = [
	ResourceSpec.new("clean_water", 1000.0,   0.0,  MapLocation.TYPE.VILLAGE,  false,  0.5),
	ResourceSpec.new("grey_water",  4000.0,   0.0,  MapLocation.TYPE.VILLAGE,  false,  0.3),
	ResourceSpec.new("scrap",       20000.0,  0.0,  MapLocation.TYPE.TOWN,     false,  0.2),
	ResourceSpec.new("oil",         200.0,    0.0,  MapLocation.TYPE.CITY,     true,   0.6),
	ResourceSpec.new("oil",         2000.0,   0.0,  MapLocation.TYPE.VILLAGE,  true,   0.4),
	ResourceSpec.new("food1",       4200.0,   0.0,  MapLocation.TYPE.TOWN,     false,  0.1),
	ResourceSpec.new("pop",         500.0,    0.0,  MapLocation.TYPE.VILLAGE,  false,  0.2),
	ResourceSpec.new("mech_parts",  300.0,    0.0,  MapLocation.TYPE.CITY,     false,  0.7)
]

var variability : float = 0.8 # Proportion up or down resources vary per city

func add_resources_to_map_graph(_mapGraph : MapGraph) -> void:
	self.mapGraph = _mapGraph
	cities_first_pass()
	nodes_second_pass()

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
			# Rarity check - chance for cities to be skipped
			if remainingLocations > 1 && randf() < resourceSpec.rarity:
				remainingLocations -= 1
				continue
			
			var amount_to_place : float = total_remaining / float(remainingLocations) * randf_range(1 - variability, 1 + variability)
			amount_to_place = max(amount_to_place, resourceSpec.min_per_location)
			var resource_container : MapResourceContainer = MapResourceContainer.new(
				resourceSpec.resource_type,
				amount_to_place
			)
			resource_container.rarity = resourceSpec.rarity
			remainingLocations -= 1
			total_remaining -= amount_to_place
			location.add_resource_container(resource_container)


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
			if remainingLocations > 1 and randf() < resourceSpec.rarity:
				remainingLocations -= 1
				continue

			var share: float = total_remaining / float(remainingLocations) *  randf_range(1 - variability, 1 + variability)
			var amount_to_place: float = share
			if resourceSpec.min_per_location > 0.0:
				amount_to_place = maxf(share, resourceSpec.min_per_location)
			amount_to_place = minf(amount_to_place, total_remaining)

			var resource_container: MapResourceContainer = MapResourceContainer.new(
				resourceSpec.resource_type,
				amount_to_place
			)
			resource_container.rarity = resourceSpec.rarity
			location.add_resource_container(resource_container)
			remainingLocations -= 1
			total_remaining -= amount_to_place
