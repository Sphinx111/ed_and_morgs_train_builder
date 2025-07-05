extends ProductionProvider

class_name ScrapToMechProducer

## Set up the Production Provider's variables
func init() -> void:
	inputType1 = "scrap"
	input1_needed = 5
	
	outputType1 = "mech_parts"
	output1_amount = 1
	
	cycleTime = 2
