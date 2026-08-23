extends Resource

class_name ProductionRecipe

enum UsageMode { NONE, BOTH, EITHER }

@export var cycle_time: int = 1
@export var input_mode: UsageMode = UsageMode.BOTH

@export var input_type_1: String = ""
@export var input_1_needed: float = 0.0
@export var input_1_from_map: bool = false

@export var input_type_2: String = ""
@export var input_2_needed: float = 0.0

@export var output_type_1: String = ""
@export var output_1_amount: float = 0.0

@export var output_type_2: String = ""
@export var output_2_amount: float = 0.0

@export var max_speed: float = -1.0
