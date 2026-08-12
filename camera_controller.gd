extends Camera2D
class_name TrainCamera

const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 2.0
const ZOOM_WHEEL_STEP: float = 0.08
const PAN_SPEED: float = 500.0

@export var starting_vertical_offset: float = 0.0
@export var target_vertical_offset: float = 80.0
@export var shift_pan_speed_multiplier: float = 2.5

var _pan_offset: Vector2 = Vector2.ZERO
var _zoom_level: float = 1.0


func _ready() -> void:
	make_current()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()


func _on_viewport_size_changed() -> void:
	_apply_transform()


func _apply_transform() -> void:
	var zoom_vertical_offset: float = _get_zoom_vertical_offset()
	offset = _get_viewport_center() + _pan_offset + Vector2(0.0, zoom_vertical_offset)
	zoom = Vector2(_zoom_level, _zoom_level)


func _get_zoom_vertical_offset() -> float:
	var zoom_blend: float = inverse_lerp(MIN_ZOOM, MAX_ZOOM, _zoom_level)
	return lerpf(starting_vertical_offset, target_vertical_offset, zoom_blend)


func _get_viewport_center() -> Vector2:
	return get_viewport().get_visible_rect().size * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_zoom(ZOOM_WHEEL_STEP)
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_zoom(-ZOOM_WHEEL_STEP)
			get_viewport().set_input_as_handled()


func _change_zoom(delta: float) -> void:
	_zoom_level = clampf(_zoom_level + delta, MIN_ZOOM, MAX_ZOOM)
	_apply_transform()


func _process(delta: float) -> void:
	var pan_direction: float = Input.get_action_strength("camera_right") - Input.get_action_strength("camera_left")
	if pan_direction == 0.0:
		return
	var pan_speed: float = PAN_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		pan_speed *= shift_pan_speed_multiplier
	_pan_offset.x += pan_direction * pan_speed * delta / _zoom_level
	_apply_transform()


static func viewport_to_world(viewport: Viewport, viewport_position: Vector2) -> Vector2:
	return viewport.get_canvas_transform().affine_inverse() * viewport_position
