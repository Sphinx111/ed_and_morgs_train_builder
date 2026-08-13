extends ProductionProvider

class_name BasicScrapCollector

## Set up the Production Provider's variables
func init() -> void:
	inputType1 = "scrap"
	input1_needed = 5.0
	input1_from_map = true

	outputType1 = "scrap"
	output1_amount = 5.0

	max_speed = 110

	cycleTime = 1
