@tool
extends Resource

## The amount and coverage of one resource type at one settlement size (village, town or
## city) - or, reused for the Trainyard specs, the same shape for train-car counts instead.
## Everything here is deterministic: every location that receives this resource gets exactly
## `amount`, with no random variation between locations.
class_name ResourceSpec

## Percentage of locations of this settlement size that end up with this resource at all.
## 100 = every location of this size gets it, 0 = never placed here.
@export_range(0.0, 100.0, 1.0) var coverage_percent: float = 50.0
## Amount placed at a location that receives this resource, as a single deposit/container.
@export_range(0.0, 20000.0, 10.0, "or_greater") var amount: float = 100.0
## Relative weight when a location's "discover a random resource" pick chooses among what's
## there - higher means it tends to get revealed before other resources at the same spot.
## Not used for the Trainyard specs.
@export_range(0.0, 5.0, 0.05) var visibility: float = 0.3
