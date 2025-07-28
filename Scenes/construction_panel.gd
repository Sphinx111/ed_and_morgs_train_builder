extends Panel

class_name ConstructionPanel

var buttons : Array [Button] = []

func setup():
	var newButton = Button.new()
	newButton.text="amaazign"
	add_child(newButton)
	buttons.append(newButton)
	newButton.text="%d" % buttons.size()
	newButton.position.x = buttons.size() * 50 + 10
	newButton.pressed.connect(pressButton.bind(newButton.text))
	
func pressButton(textyargument):
	print ("%s amazingnesses achieved" % textyargument)
	
