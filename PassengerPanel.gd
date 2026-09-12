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
	actionLabel.text = " Coding it so the action label is accurate"

func update_step() -> void:
	thirstBar.size.x = passenger.wants_need("thirst") * bar_width
	hungerBar.size.x = passenger.wants_need("hunger") * bar_width
	socialBar.size.x = passenger.wants_need("social") * bar_width
	illnessBar.size.x = passenger.wants_need("illness") * bar_width
	restBar.size.x = passenger.wants_need("rest") * bar_width
	if passenger.is_in_module:
		actionLabel.text = ("working at %s" if passenger.is_working else "served by %s") % passenger.current_module.type
	else:
		var last_thought : String = passenger.get_last_thought_text()
		actionLabel.text = last_thought if last_thought != "" else "Wandering"
	return
