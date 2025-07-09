extends ProductionProvider

class_name BasicCleanWaterProducer

## Set up the Production Provider's variables
func init() -> void:
	input_mode = Globals.USE_EITHER
	
	inputType1 = "black_water"
	input1_needed = 0.5
	
	inputType2 = "grey_water"
	input2_needed = 0.5
	
	outputType1 = "clean_water"
	output1_amount = 0.5
	
	cycleTime = 4
