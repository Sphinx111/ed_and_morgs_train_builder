extends Node2D

class_name TraincarAddonBase

## A roof-mounted addon (radio antenna, kite sail, ...). One per traincar, separate from the
## car's 4 module slots. All effect config for an addon type lives in a single
## TraincarAddonDefinitionRegistry entry; this class dispatches to whichever effect kind(s) that
## entry declares:
##  - "capability_feature"/"capability_amount": a train-wide effect via TrainCapability, same
##    Globals-mutation pattern ModuleBase uses (e.g. antenna_count, kite_sail_count).
##  - "car_stats": a Dictionary of stat_name -> amount applied additively onto parentCar's own
##    car_stats, scoped to just this car (e.g. heat_resistance, luxury_rating).
##  - "passive_production": a trickle of one resource per tick, optionally gated to only run
##    while the train is not in sunlight (e.g. a moisture collector).

var parentCar : TraincarBase = null
var parentTrain : Train = null
var type : String = "empty"

var capability_feature : String = ""
var capability_amount : int = 0
var _capability_applied : bool = false

var _applied_car_stats : Dictionary = {}

var passive_resource_type : String = ""
var passive_amount_per_tick : float = 0.0
var passive_requires_shade : bool = false

const ROOF_HEIGHT : float = 20.0

var _click_area : Area2D = null


func _ready() -> void:
	parentCar = get_parent()
	parentTrain = parentCar.get_parent()
	position.y = -ROOF_HEIGHT
	_setup_click_area()


func set_type(newType : String) -> void:
	reset_addon()
	type = newType
	if newType == "empty":
		_update_click_area_enabled()
		return

	var config := TraincarAddonDefinitionRegistry.get_definition(newType)
	if config.is_empty():
		push_warning("TraincarAddonBase.set_type: unknown addon type '%s'" % newType)
		$Label.text = newType
		_update_click_area_enabled()
		return

	$Outline.color = config.get("outline_color", Color.GRAY)
	$Outline.visible = true
	$Label.text = TraincarAddonDefinitionRegistry.get_display_label(newType)

	_configure_capability(config)
	_configure_car_stats(config)
	_configure_passive_production(config)

	_update_click_area_enabled()


## Per-tick trickle production (e.g. moisture collector). Called from TraincarBase.resource_tick().
func resource_tick() -> void:
	if passive_resource_type == "" or passive_amount_per_tick == 0.0:
		return
	if passive_requires_shade and parentTrain.is_in_sunlight():
		return
	parentTrain.add_res(passive_resource_type, passive_amount_per_tick)


func reset_addon() -> void:
	_remove_capability()
	_remove_car_stats()
	_reset_passive_production()
	type = "empty"
	$Outline.color = Color.GRAY
	$Outline.visible = false
	$Label.text = "Empty"


func _configure_capability(config: Dictionary) -> void:
	capability_feature = config.get("capability_feature", "")
	capability_amount = config.get("capability_amount", 0)
	_apply_capability()


func _apply_capability() -> void:
	if capability_feature == "" or capability_amount == 0 or _capability_applied:
		return
	TrainCapability.apply(capability_feature, capability_amount)
	_capability_applied = true


func _remove_capability() -> void:
	if not _capability_applied:
		return
	TrainCapability.remove(capability_feature, capability_amount)
	_capability_applied = false
	capability_feature = ""
	capability_amount = 0


func _configure_car_stats(config: Dictionary) -> void:
	var stats : Dictionary = config.get("car_stats", {})
	if stats.is_empty() or parentCar == null:
		return
	for stat_name in stats:
		var amount : float = stats[stat_name]
		parentCar.car_stats[stat_name] = parentCar.car_stats.get(stat_name, 0.0) + amount
		_applied_car_stats[stat_name] = amount


func _remove_car_stats() -> void:
	if _applied_car_stats.is_empty() or parentCar == null:
		_applied_car_stats.clear()
		return
	for stat_name in _applied_car_stats:
		var amount : float = _applied_car_stats[stat_name]
		parentCar.car_stats[stat_name] = parentCar.car_stats.get(stat_name, 0.0) - amount
	_applied_car_stats.clear()


func _configure_passive_production(config: Dictionary) -> void:
	var production : Dictionary = config.get("passive_production", {})
	if production.is_empty():
		return
	passive_resource_type = production.get("resource_type", "")
	passive_amount_per_tick = production.get("amount_per_tick", 0.0)
	passive_requires_shade = production.get("requires_shade", false)


func _reset_passive_production() -> void:
	passive_resource_type = ""
	passive_amount_per_tick = 0.0
	passive_requires_shade = false


func _setup_click_area() -> void:
	_click_area = Area2D.new()
	_click_area.name = "ClickArea"
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(Globals.car_length, ROOF_HEIGHT)
	shape_node.shape = shape
	shape_node.position = Vector2(Globals.car_length * 0.5, ROOF_HEIGHT * 0.5)
	_click_area.add_child(shape_node)
	add_child(_click_area)
	_click_area.input_event.connect(_on_click_area_input_event)
	_update_click_area_enabled()


func update_click_area() -> void:
	_update_click_area_enabled()


func _update_click_area_enabled() -> void:
	if _click_area != null:
		var in_placement := Globals.activeUI is TrainUI and Globals.activeUI.pending_addon_type != ""
		_click_area.input_pickable = in_placement


func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if Globals.activeUI is TrainUI and Globals.activeUI.pending_addon_type != "":
		if event is InputEventMouseButton and event.is_action_pressed("left_click"):
			Globals.activeUI.place_addon_at_car(parentCar.sequence)
			get_viewport().set_input_as_handled()
