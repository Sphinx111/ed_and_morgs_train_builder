@tool
extends Control

class_name ResourceDistributionReport

## Standalone editor tool (no need to run the game): a direct visual read of
## MapResourceGenerator's per-settlement-size ResourceSpec dictionaries - one bar chart each
## for Village, Town and City, showing coverage % and amount per resource type. No
## simulation - this is a straight display of the actual default values, not an estimate.
##
## Deliberately read-only: refresh() builds a fresh MapResourceGenerator.new() every time
## instead of reading a node stored in this scene, so there's no scene-local copy of the
## specs sitting here that could drift out of sync with the real defaults
## MapResourceGenerator.gd ships with (that drift is exactly what a saved child node's own
## Inspector overrides used to risk). To change the numbers, edit the _default_*_specs()
## functions in MapResourceGenerator.gd (or the MapResourceGenerator node's Inspector in
## world_map.tscn, which uses those same defaults), then hit Refresh again to see the update
## here.
##
## Open this scene directly in the editor and it renders once automatically. Hit "Refresh"
## (in the Inspector, since scene-tree Controls don't receive clicks while the editor is just
## viewing a scene rather than running it) any time you want to re-check against the current
## code defaults.

@export_tool_button("Refresh") var _refresh_action: Callable = refresh

@onready var _status_label: Label = $Margin/Layout/StatusLabel
@onready var _village_chart: ResourceBarChart = $Margin/Layout/Charts/VillageColumn/VillageChart
@onready var _town_chart: ResourceBarChart = $Margin/Layout/Charts/TownColumn/TownChart
@onready var _city_chart: ResourceBarChart = $Margin/Layout/Charts/CityColumn/CityChart


func _ready() -> void:
	refresh()


func refresh() -> void:
	# A fresh instance every refresh, never a node stored in this scene - see the class doc
	# comment above for why. One side effect: the "stale placeholder" risk a scene-tree node
	# can hit after a script edit (needing the scene tab closed and reopened) doesn't apply to
	# this instance, since it's constructed fresh right here rather than loaded from the .tscn.
	var generator := MapResourceGenerator.new()

	# The chart nodes are still real scene-tree children though, so they can still go stale -
	# ResourceBarChart's base class changed recently (Control -> VBoxContainer), which is
	# exactly the kind of script edit that can leave an already-open scene tab's node
	# instances stale until it's reopened, so check before calling set_specs() on them.
	if _village_chart == null or not is_instance_valid(_village_chart) or not _village_chart.has_method("set_specs") \
			or _town_chart == null or not is_instance_valid(_town_chart) or not _town_chart.has_method("set_specs") \
			or _city_chart == null or not is_instance_valid(_city_chart) or not _city_chart.has_method("set_specs"):
		if _status_label != null:
			_status_label.text = "Chart nodes aren't live - close and reopen this scene tab (or Project > Reload Current Project), then hit Refresh again."
		generator.free()
		return

	_village_chart.set_specs(generator.villageResourceSpecs)
	_town_chart.set_specs(generator.townResourceSpecs)
	_city_chart.set_specs(generator.cityResourceSpecs)
	generator.free()

	if _status_label != null:
		_status_label.text = "Showing MapResourceGenerator's current default values - hit Refresh again after editing _default_*_specs()."
