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
var active_event : NarrativeEvent

func start() -> void:
	main_timer.wait_time = first_event_time
	main_timer.one_shot = true
	main_timer.timeout.connect(_on_main_timer_timeout)
	add_child(main_timer)
	main_timer.start()


func _on_main_timer_timeout() -> void:
	active_event = NarrativeEvent.new("someType")
	active_popup = popupScene.instantiate()
	var ui_canvas: CanvasLayer = get_parent().get_node("UICanvas")
	ui_canvas.add_child(active_popup)
	_connect_signals()
	active_popup.set_event(active_event)

func _connect_signals():
	active_popup.option1.connect(_on_option1)
	active_popup.option2.connect(_on_option2)
	active_popup.option3.connect(_on_option3)

func cleanup_dialogbox() -> void:
	active_popup.queue_free()
	active_popup = null

func _on_option1():
	print("option1 pressed")
	train.eventProcessor.handle_event(active_event.narrativeResults[0])
	cleanup_dialogbox()
	pass

func _on_option2():
	print("option2 pressed")
	train.eventProcessor.handle_event(active_event.narrativeResults[1])
	cleanup_dialogbox()
	pass

func _on_option3():
	print("option3 pressed")
	train.eventProcessor.handle_event(active_event.narrativeResults[2])
	cleanup_dialogbox()
	pass
