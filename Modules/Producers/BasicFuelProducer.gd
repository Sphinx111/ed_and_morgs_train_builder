extends ProductionProvider

class_name BasicFuelProducer

## Set up the Production Provider's variables
func init() -> void:
	input_mode = Globals.USE_EITHER
	
	inputType1 = "oil"
	input1_needed = 5.0
	
	inputType2 = "clean_water"
	input2_needed = 1.0
	
	outputType1 = "fuel"
	output1_amount = 5.0
	
	outputType2 = "grey_water"
	output2_amount = 1.0
	
	cycleTime = 10
