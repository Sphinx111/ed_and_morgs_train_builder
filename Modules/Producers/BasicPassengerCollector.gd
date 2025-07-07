extends ProductionProvider

class_name BasicPassengerCollector

## Set up the Production Provider's variables
func init() -> void:
	inputType1 = "pop"
	input1_needed = 5.0
	input1_from_map = true

	outputType1 = "pop"
	output1_amount = 1.0

	cycleTime = 1
