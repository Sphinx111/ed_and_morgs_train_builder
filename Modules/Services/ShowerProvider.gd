extends ServiceProvider

class_name ShowerProvider

func init():
 trigger_once = true

 outputType = "rest"
 outputRate = 0.1

 inputType1 = "clean_water"
 input1_needed = 10.0

 wasteType1 = "grey_water"
 waste1_produced = 10.0
