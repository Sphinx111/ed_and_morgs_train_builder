extends Panel

class_name PassengerPanel

var passenger : Passenger = null
var nameLabel : Label = null
var actionLabel : Label = null
var thirstBar : ColorRect = null
var hungerBar : ColorRect = null
var socialBar : ColorRect = null
var illnessBar : ColorRect = null
var restBar : ColorRect = null

var bar_width : float = 0.0

func _ready() -> void:
	passenger = get_parent()
	nameLabel = get_node("NameLabel")
	actionLabel = get_node("ActionLabel")
	thirstBar = get_node("ThirstBar")
	hungerBar = get_node("HungerBar")
	socialBar = get_node("SocialBar")
	illnessBar = get_node("IllnessBar")
	restBar = get_node("RestBar")
	bar_width = thirstBar.size.x
	nameLabel.text = passenger.firstname + " " + passenger.lastname
	actionLabel.text = " Coding t so the action label is accurate"

func update_step() -> void:
	thirstBar.size.x = passenger.needs["thirst"] * bar_width
	hungerBar.size.x = passenger.needs["hunger"] * bar_width
	socialBar.size.x = passenger.needs["social"] * bar_width
	illnessBar.size.x = passenger.needs["illness"] * bar_width
	restBar.size.x = passenger.needs["rest"] * bar_width
	return
