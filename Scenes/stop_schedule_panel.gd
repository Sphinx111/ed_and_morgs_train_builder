extends Panel

class_name StopSchedulePanel

var buttons : Array [Button]
var buttonList : Array [String] = ["grey_water", "clean_water", "oil", "pop", "scrap", "mech_parts","food1", "unknown"]
@onready var vBox : VBoxContainer = get_node("VBoxContainer")

func setup() : 
	var i=0
	if buttons.size() == 0:
		for nameb in buttonList : 
			var newButton : Button = Button.new() 
			vBox.add_child(newButton)
			newButton.text = nameb
			newButton.pressed.connect(resourceSelectPress.bind(newButton.text))
			buttons.append(newButton)
			i+=1
		## add special button wired up for cancelling
		var cancelButton : Button = Button.new() 
		vBox.add_child(cancelButton)
		cancelButton.text = "Cancel"
		cancelButton.pressed.connect(resourceSelectPress.bind(""))
		buttons.append(cancelButton)

func resourceSelectPress(resourceSelection) : 
	buttonHighlight(resourceSelection)
	var ourMap : MapHandler = get_parent().worldMap
	ourMap.set_schedule_stop(resourceSelection)
	#var nextResource : MapDestination = ourMap.get_next_resource_spot(resourceSelection)
	var resourceDist : float = ourMap.get_distance_to_next_resource(resourceSelection)
	if resourceDist > -9990 :
		print("Next %s Well is at %f" % [resourceSelection, resourceDist])	
	else :
		print ("No %s Well is available along current route" % [resourceSelection])
		
func buttonHighlight(selectedText):
	for buttonb in buttons :
		if buttonb.text == selectedText :
			buttonb.disabled = true
			#buttonb.font_color = Color("#ff5f5f")
		else :
			buttonb.disabled = false
			#buttonb.font_color = Color("#dfdfdf")

func cleanup_buttons():
	pass
