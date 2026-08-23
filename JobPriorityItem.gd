extends Panel

class_name JobPriorityItem

var plus_button : Button = null
var minus_button : Button = null
var type_label : Label = null
var jobsController : JobsController = null

var initial_y_offset = 40
var myHeight = self.size.y
var separation = 5            ## Separation between Job Priority Items

@export var myType : String = ""
@export var myIndex : int = 0

var increase_priority_callable = null
var decrease_priority_callable = null

func _ready():
	jobsController = get_parent()
	plus_button = get_node("IncreasePriority")
	minus_button = get_node("ReducePriority")
	type_label = get_node("TypeLabel")
	type_label.text = _format_category_label(myType)
	increase_priority_callable = jobsController._on_job_increase_pressed.bind(myIndex)
	decrease_priority_callable = jobsController._on_job_decrease_pressed.bind(myIndex)
	plus_button.pressed.connect(increase_priority_callable)
	minus_button.pressed.connect(decrease_priority_callable)


func _format_category_label(category: String) -> String:
	if category == "":
		return ""
	return category.replace("_", " ").capitalize()


## Visual movement and index change
func _change_index(new_index : int):
	myIndex = new_index
	self.position.y = initial_y_offset + (myIndex * (myHeight + separation))
	plus_button.pressed.disconnect(increase_priority_callable)
	minus_button.pressed.disconnect(decrease_priority_callable)
	increase_priority_callable = jobsController._on_job_increase_pressed.bind(myIndex)
	decrease_priority_callable = jobsController._on_job_decrease_pressed.bind(myIndex)
	plus_button.pressed.connect(increase_priority_callable)
	minus_button.pressed.connect(decrease_priority_callable)
