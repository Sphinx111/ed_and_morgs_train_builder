extends ProductionProvider

class_name BasicFood1Producer

## Set up the Production Provider's variables
func init() -> void:
	input_mode = Globals.USE_EITHER
	
	inputType1 = "grey_water"
	input1_needed = 5.0
	
	inputType2 = "clean_water"
	input2_needed = 5.0
	
	outputType1 = "food1"
	output1_amount = 5.0
	
	cycleTime = 10
