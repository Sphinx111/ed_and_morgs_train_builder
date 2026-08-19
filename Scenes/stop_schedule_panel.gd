extends Panel

class_name StopSchedulePanel

var buttons : Array [Button]
var buttonList : Array [String] = ["water", "oil", "people"]

func setup() : 
	var i=0
	for nameb in buttonList : 
		var newButton : Button = Button.new() 
		add_child(newButton)
		newButton.text = nameb
		newButton.position = Vector2(0,i*50)
		buttons.append(newButton)
		i+=1
	
