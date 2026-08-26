extends Resource

class_name ServiceRecipe

enum InputMode {
	USE_BOTH,
	USE_EITHER,
}

@export var trigger_once: bool = false
@export var output_need: String = ""
@export var output_rate: float = 0.0

@export var input_mode: InputMode = InputMode.USE_BOTH

@export var input_type_1: ResourceType
@export var input_1_needed: float = 0.0

@export var input_type_2: ResourceType
@export var input_2_needed: float = 0.0

@export var waste_type_1: ResourceType
@export var waste_1_produced: float = 0.0
