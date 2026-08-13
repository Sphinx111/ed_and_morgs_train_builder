extends Node

## This class triggers and selects Narrative events to show to the player
class_name NarrativeEngine

var train : Train

func _init(newTrain : Train) -> void:
	train = newTrain

## The earliest an event can happen in seconds
var first_event_time : float = 5.0
var main_timer : Timer = Timer.new()

## How fast time progresses whilst the player is reading the event
var event_sim_speed : float = 0.1

var popupScene : PackedScene = preload("res://Scenes/dialog_popup.tscn")
var active_popup : DialogPopup
var active_event
var _saved_time_factor : float = 1.0

var next_event : int = 0
var planned_events : Array[String] = ["startingOut","treeGuy"]

func start() -> void:
	main_timer.wait_time = first_event_time
	main_timer.one_shot = true
	main_timer.timeout.connect(_on_main_timer_timeout)
	add_child(main_timer)
	main_timer.start()


func _on_main_timer_timeout() -> void:
	if next_event >= planned_events.size():
		return
	active_event = NarrativeEvent.new(planned_events[next_event])
	active_popup = popupScene.instantiate()
	var ui_canvas: CanvasLayer = get_parent().get_node("UICanvas")
	ui_canvas.add_child(active_popup)
	active_popup.set_event(active_event) ## must be called after being added to scene tree
	_connect_signals()
	## Save time factor and slow time down
	_saved_time_factor = Globals.time_factor
	EventBus.request_time_factor(event_sim_speed)

func _connect_signals():
	active_popup.event_finished.connect(_receive_event_outcome)

func cleanup_dialogbox() -> void:
	EventBus.request_time_factor(_saved_time_factor)
	active_popup.queue_free()
	active_popup = null

func _receive_event_outcome(eventResult : TrainEvent) -> void:
	train.eventProcessor.handle_event(eventResult)
	print("eventResult is %d" % eventResult.eventType)
	cleanup_dialogbox()
	
	next_event += 1
	main_timer.start()
