extends RefCounted

## Everything about what a scavenge expedition actually reveals at a location lives here,
## rather than spread across ActiveExpedition/MapLocation - a location's resource_containers
## can hold both "reserve" containers (undiscovered - the full amount MapResourceGenerator
## placed there) and "deposit" containers (discovered - created by a previous scavenge,
## ready to collect). A scavenge no longer reveals a reserve's full amount in one go: it
## splits off DISCOVERY_PORTION of whatever remains as its own new discovered deposit,
## leaving the rest of the reserve for future scavenges to chip away at.
class_name ExpeditionDiscoveryHelper

## Fraction of a reserve's remaining amount revealed per scavenge. To start with this is a
## flat 10% - tune freely, or make it vary per resource/expedition later.
const DISCOVERY_PORTION: float = 0.10

## Below this remaining amount, a reserve is handed over in full rather than left behind -
## 10% of what's left never mathematically reaches zero, so without this a location would
## stay "has undiscovered resources" forever, just with vanishingly small future reveals.
const MIN_REMAINING_RESERVE: float = 40.0
const MIN_REMAINING_RESERVE_POP: float = 4.0

## Once a location has this many active (i.e. not yet fully collected) discovered deposits of
## a given resource type, no more of that type can be discovered there. As soon as a deposit
## is collected down to empty it stops counting toward this cap, freeing up a slot so that
## type can be discovered again.
const MAX_DEPOSITS_PER_TYPE: int = 3

## When a location has at least one resource type already discovered AND at least one type
## never discovered there yet, a reserve of one of those brand-new types has its selection
## weight multiplied by this - expeditions lean toward spreading discovery across resource
## types rather than piling everything into whatever type was found first.
const NEW_TYPE_WEIGHT_MULTIPLIER: float = 3.0


## Picks one eligible undiscovered reserve at the location (weighted by visibility, with new
## resource types boosted - see NEW_TYPE_WEIGHT_MULTIPLIER), splits off a portion of what's
## left as a new discovered deposit, and returns that deposit.
## Returns null - and reveals nothing - if the location has nothing left it's allowed to
## discover: either every reserve is empty, or every remaining type already has
## MAX_DEPOSITS_PER_TYPE active deposits outstanding. Callers should treat a null return as
## the scavenge finding nothing.
static func discover_portion(location: MapLocation) -> MapResourceContainer:
	if location == null:
		return null

	var reserve: MapResourceContainer = _pick_weighted_undiscovered(location)
	if reserve == null:
		if Globals.MAP_GEN_DEBUG:
			print("ExpeditionDiscoveryHelper:: no eligible reserve to discover at ", location.name)
		return null

	var revealed_amount: float = reserve.amount * DISCOVERY_PORTION
	reserve.amount -= revealed_amount

	if reserve.resource_type == "pop":
		if reserve.amount <= MIN_REMAINING_RESERVE_POP:
			revealed_amount += reserve.amount
			reserve.amount = 0.0
	else:
		if reserve.amount <= MIN_REMAINING_RESERVE:
			revealed_amount += reserve.amount
			reserve.amount = 0.0

	var deposit := MapResourceContainer.new(reserve.resource_type, revealed_amount)
	deposit.visibility = reserve.visibility
	deposit.discovered = true
	location.add_resource_container(deposit)
	return deposit


static func _pick_weighted_undiscovered(location: MapLocation) -> MapResourceContainer:
	var all_containers: Array[MapResourceContainer] = location.get_resource_containers()

	var candidates: Array[MapResourceContainer] = []
	for container in all_containers:
		if not container.discovered and not container.is_empty() \
				and _discovered_deposit_count(all_containers, container.resource_type) < MAX_DEPOSITS_PER_TYPE:
			candidates.append(container)
	if candidates.is_empty():
		return null

	var boost_new_types: bool = _has_discovered_type(all_containers) and _has_undiscovered_type_among(candidates, all_containers)

	var weights: Array[float] = []
	var total_weight: float = 0.0
	for container in candidates:
		var weight: float = container.visibility
		if boost_new_types and _discovered_deposit_count(all_containers, container.resource_type) == 0:
			weight *= NEW_TYPE_WEIGHT_MULTIPLIER
		weights.append(weight)
		total_weight += weight

	if total_weight <= 0.0:
		return candidates[randi() % candidates.size()]

	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for i in range(candidates.size()):
		cumulative += weights[i]
		if roll < cumulative:
			return candidates[i]
	return candidates[candidates.size() - 1]


## How many discovered deposits of _type currently still have resources left at this
## location. A deposit collected down to empty no longer counts, which is what frees up a
## slot toward MAX_DEPOSITS_PER_TYPE for that type to be discovered again.
static func _discovered_deposit_count(all_containers: Array[MapResourceContainer], _type: String) -> int:
	var count: int = 0
	for container in all_containers:
		if container.discovered and not container.is_empty() and container.resource_type == _type:
			count += 1
	return count


## True if at least one resource type at this location has already been discovered.
static func _has_discovered_type(all_containers: Array[MapResourceContainer]) -> bool:
	for container in all_containers:
		if container.discovered:
			return true
	return false


## True if at least one of the given candidates is of a resource type with no active
## discovered deposit at this location right now - either never discovered yet, or
## discovered and since fully depleted (see _discovered_deposit_count). A type in that state
## can never be over MAX_DEPOSITS_PER_TYPE, so this only needs to check the candidates
## already on offer.
static func _has_undiscovered_type_among(candidates: Array[MapResourceContainer], all_containers: Array[MapResourceContainer]) -> bool:
	for container in candidates:
		if _discovered_deposit_count(all_containers, container.resource_type) == 0:
			return true
	return false
