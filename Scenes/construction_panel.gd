extends Panel

class_name ConstructionPanel

var buttons : Array [Button] = []

func setup():
	var newButton = Button.new()
	var buttonList = ["water", "food", "kitchen", "cabin"]
	for buttonWord in buttonList:
		newButton = Button.new()
		newButton.text=buttonWord
		add_child(newButton)
		buttons.append(newButton)
		newButton.position.x = buttons.size() * 60 + 10
		newButton.pressed.connect(pressButton.bind(newButton.text))
	
func pressButton(textyargument):
	# $LineEdit.text = 
	print ("add %s at" % textyargument)
#	$selectCarPanel.show()
	
