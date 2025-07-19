extends ProductionProvider

class_name BasicWaterCollector

## Set up the Production Provider's variables
func init() -> void:
	inputType1 = "grey_water"
	input1_needed = 10.0
	input1_from_map = true
	max_speed = 0

	outputType1 = "grey_water"
	output1_amount = 10.0

	cycleTime = 1
