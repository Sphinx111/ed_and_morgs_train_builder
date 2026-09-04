extends Node2D

## Visual marker and resource deposit for a train yard on the world map.
class_name MapResourceLocation

const RESOURCE_TYPE: String = "trainCars"
const GATHER_TIME: int = 1200  ## 20 minutes at 1 person; actual time is GATHER_TIME / expedition size

var resource_container: MapResourceContainer = null


static func attach_to(location: MapLocation, train_car_count: float = 1.0) -> MapResourceLocation:
	var yard := MapResourceLocation.new()
	yard.name = "TrainYard"
	location.add_child(yard)
	yard._configure(location, train_car_count)
	return yard


func _configure(location: MapLocation, train_car_count: float) -> void:
	resource_container = MapResourceContainer.new(RESOURCE_TYPE, train_car_count)
	resource_container.discovered = true
	location.add_resource_container(resource_container)
	_setup_visual()


func _setup_visual() -> void:
	var outline := Line2D.new()
	outline.name = "Outline"
	outline.width = 2.0
	outline.default_color = Color(0.85, 0.55, 0.15, 0.95)
	outline.points = PackedVector2Array([
		Vector2(-10.0, -10.0),
		Vector2(10.0, -10.0),
		Vector2(10.0, 10.0),
		Vector2(-10.0, 10.0),
		Vector2(-10.0, -10.0),
	])
	add_child(outline)

	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.color = Color(0.85, 0.55, 0.15, 0.25)
	fill.polygon = PackedVector2Array([
		Vector2(-10.0, -10.0),
		Vector2(10.0, -10.0),
		Vector2(10.0, 10.0),
		Vector2(-10.0, 10.0),
	])
	add_child(fill)

	var label := Label.new()
	label.name = "Label"
	label.text = "Yard"
	label.position = Vector2(-14.0, -22.0)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
