extends Node

## Global signal hub for decoupled game events.
signal time_factor_requested(new_time_factor: float)


func request_time_factor(new_time_factor: float) -> void:
	time_factor_requested.emit(new_time_factor)
