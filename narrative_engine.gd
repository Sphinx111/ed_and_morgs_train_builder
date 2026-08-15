extends Node

## This class triggers and selects Narrative events to show to the player
class_name NarrativeEngine

class ScheduledStoryEvent:
	var event_key: String
	var start_time: float

	func _init(key: String, start: float) -> void:
		event_key = key
		start_time = start


var train: Train

## Seconds before the first scripted storyline event can trigger
var first_event_time: float = 5.0
## How often the engine checks the scheduled event pool
var poll_interval: float = 0.25
## How fast time progresses whilst the player is reading an event
var event_sim_speed: float = 0.1

var popupScene: PackedScene = preload("res://Scenes/dialog_popup.tscn")
var active_popup: DialogPopup
var active_event: NarrativeEvent
var _saved_time_factor: float = 1.0
var _dialog_active: bool = false
var _story_time: float = 0.0
var _scheduled_events: Array = []
var _entry_event_queue: Array[String] = ["treeGuy"]

var _poll_timer: Timer = Timer.new()


func _init(newTrain: Train) -> void:
	train = newTrain


func start() -> void:
	return
	NarrativeEventLoader.load_all()
	_poll_timer.wait_time = poll_interval
	_poll_timer.timeout.connect(_on_poll_timer_timeout)
	add_child(_poll_timer)
	_poll_timer.start()
	_schedule_event("startingOut", first_event_time)


func _process(delta: float) -> void:
	if _dialog_active:
		return
	_story_time += delta * Globals.time_factor


func _on_poll_timer_timeout() -> void:
	if _dialog_active:
		return
	_try_trigger_ready_event()


func _schedule_event(event_key: String, start_time: float) -> void:
	_scheduled_events.append(ScheduledStoryEvent.new(event_key, start_time))


func _try_trigger_ready_event() -> void:
	var best_index: int = -1
	var best_time: float = INF
	for i in range(_scheduled_events.size()):
		var entry: ScheduledStoryEvent = _scheduled_events[i]
		if entry.start_time <= _story_time and entry.start_time < best_time:
			best_time = entry.start_time
			best_index = i
	if best_index < 0:
		return
	var picked: ScheduledStoryEvent = _scheduled_events[best_index]
	_scheduled_events.remove_at(best_index)
	_show_event(picked.event_key)


func _show_event(event_key: String) -> void:
	active_event = NarrativeEventLoader.get_event(event_key)
	if active_event == null:
		push_error("NarrativeEngine: missing narrative event '%s'" % event_key)
		return
	active_popup = popupScene.instantiate()
	var ui_canvas: CanvasLayer = get_parent().get_node("UICanvas")
	ui_canvas.add_child(active_popup)
	active_popup.set_event(active_event)
	_connect_signals()
	_dialog_active = true
	_saved_time_factor = Globals.time_factor
	EventBus.request_time_factor(event_sim_speed)


func _connect_signals() -> void:
	active_popup.event_finished.connect(_receive_event_outcome)


func cleanup_dialogbox() -> void:
	EventBus.request_time_factor(_saved_time_factor)
	active_popup.queue_free()
	active_popup = null
	_dialog_active = false


func _receive_event_outcome(event_result: TrainEvent, next_event_key: String = "", min_delay: float = 0.0) -> void:
	train.eventProcessor.handle_event(event_result)
	cleanup_dialogbox()

	if next_event_key != "":
		_schedule_event(next_event_key, _story_time + min_delay)
	elif not _entry_event_queue.is_empty():
		var next_key: String = _entry_event_queue.pop_front()
		_schedule_event(next_key, _story_time + first_event_time)
