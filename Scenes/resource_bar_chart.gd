@tool
extends VBoxContainer

## Builds one row per resource type as real Label/ProgressBar nodes (rebuilt fresh on every
## set_specs() call) rather than a custom-drawn canvas - Godot's normal container layout and
## rendering then just handles it, with no manual redraw/sizing timing to fight with in the
## editor. Coverage uses a fixed 0-100 scale (comparable across the Village/Town/City
## charts); amount is scaled to this chart's own largest amount, since village/town/city
## amounts differ by an order of magnitude.
class_name ResourceBarChart

const ROW_MIN_HEIGHT: float = 22.0
const LABEL_MIN_WIDTH: float = 88.0
const BAR_MIN_WIDTH: float = 90.0
const VALUE_MIN_WIDTH: float = 52.0

const COVERAGE_COLOR: Color = Color(0.35, 0.65, 0.95)
const AMOUNT_COLOR: Color = Color(0.95, 0.65, 0.25)
const TRACK_COLOR: Color = Color(1.0, 1.0, 1.0, 0.08)


## Called by ResourceDistributionReport whenever it wants this chart to reflect the current
## MapResourceGenerator values - throws away and rebuilds every row.
func set_specs(specs: Dictionary[String, ResourceSpec]) -> void:
	for child in get_children():
		child.queue_free()

	var resource_types: Array[String] = specs.keys()
	resource_types.sort()

	if resource_types.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(no resources configured)"
		empty_label.modulate = Color(1.0, 1.0, 1.0, 0.6)
		add_child(empty_label)
		return

	var max_amount: float = 1.0
	for r_type in resource_types:
		max_amount = maxf(max_amount, specs[r_type].amount)

	for r_type in resource_types:
		add_child(_build_row(r_type, specs[r_type], max_amount))


func _build_row(resource_type: String, spec: ResourceSpec, max_amount: float) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = ROW_MIN_HEIGHT
	row.add_theme_constant_override("separation", 6)

	var name_label := Label.new()
	name_label.text = resource_type
	name_label.custom_minimum_size.x = LABEL_MIN_WIDTH
	name_label.clip_text = true
	row.add_child(name_label)

	row.add_child(_build_bar(spec.coverage_percent, 100.0, COVERAGE_COLOR, "%.0f%%" % spec.coverage_percent))
	row.add_child(_build_bar(spec.amount, max_amount, AMOUNT_COLOR, _format_amount(spec.amount)))

	return row


func _build_bar(value: float, max_value: float, color: Color, value_text: String) -> Control:
	var wrapper := HBoxContainer.new()
	wrapper.size_flags_horizontal = SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("separation", 6)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(BAR_MIN_WIDTH, ROW_MIN_HEIGHT)
	bar.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.min_value = 0.0
	bar.max_value = maxf(max_value, 0.001)
	bar.value = clampf(value, 0.0, bar.max_value)
	bar.show_percentage = false

	var track_style := StyleBoxFlat.new()
	track_style.bg_color = TRACK_COLOR
	bar.add_theme_stylebox_override("background", track_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = color
	bar.add_theme_stylebox_override("fill", fill_style)

	wrapper.add_child(bar)

	var value_label := Label.new()
	value_label.text = value_text
	value_label.custom_minimum_size.x = VALUE_MIN_WIDTH
	wrapper.add_child(value_label)

	return wrapper


## Local formatter (deliberately not using the Helpers autoload - singletons aren't always
## available to @tool scripts while a scene is just open for editing rather than running).
static func _format_amount(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(round(value)))
	return "%.1f" % value
