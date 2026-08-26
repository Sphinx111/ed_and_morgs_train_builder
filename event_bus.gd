extends Node

## Global signal hub for decoupled game events.
signal time_factor_requested(new_time_factor: float)
signal industry_mothballed_changed(type_name: String, mothballed: bool)


func request_time_factor(new_time_factor: float) -> void:
	time_factor_requested.emit(new_time_factor)


func request_industry_mothball(type_name: String, mothballed: bool) -> void:
	industry_mothballed_changed.emit(type_name, mothballed)
