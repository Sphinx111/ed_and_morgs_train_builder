extends Panel

class_name StopSchedulePanel

var buttons : Array [Button]
var buttonList : Array [String] = ["grey_water", "clean_water", "oil", "pop", "scrap", "mech_parts","food1"]

func setup() : 
	var i=0
	for nameb in buttonList : 
		var newButton : Button = Button.new() 
		add_child(newButton)
		newButton.text = nameb
		newButton.position = Vector2(0,i*35)
		newButton.pressed.connect(resourceSelectPress.bind(newButton.text))
		buttons.append(newButton)
		i+=1
	

func resourceSelectPress(resourceSelection) : 
	var ourMap : MapHandler = get_parent().worldMap
	ourMap.set_schedule_stop(resourceSelection)
	#var nextResource : MapDestination = ourMap.get_next_resource_spot(resourceSelection)
	var resourceDist : float = ourMap.get_distance_to_next_resource(resourceSelection)
	if resourceDist > -9990 :
		print("Next %s Well is at %f" % [resourceSelection, resourceDist])	
	else :
		print ("No %s Well is available along current route" % [resourceSelection])
