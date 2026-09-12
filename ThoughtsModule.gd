extends RefCounted

class_name ThoughtsModule

## Constructs and emits a passenger's thoughts (see PassengerThought) and owns the small
## above-the-head popup that announces one, colour-coded by sentiment, for a short time. Passenger
## composes one of these (its thoughtsModule field) and exposes single-line emit_thought() /
## get_last_thought_text() pass-throughs so other systems (PassengerNeeds, Passenger's own
## movement code, PassengerPanel) don't need to reach into thoughtsModule directly.

var passenger : Passenger

## How long the above-head popup stays visible before it hides itself again.
const POPUP_DURATION : float = 1.5

const POPUP_POSITIVE_COLOR : Color = Color(0.35, 0.82, 0.35, 1.0)
const POPUP_NEUTRAL_COLOR : Color = Color(0.65, 0.65, 0.65, 1.0)
const POPUP_NEGATIVE_COLOR : Color = Color(0.88, 0.25, 0.25, 1.0)

const REST_ICON_MODULATE : Color = Color(0.6, 0.6, 0.6, 1.0)

## How many consecutive idle ticks (no thought of any kind) must pass before chatter becomes
## possible - see tick(). Easy to retune independently of CHATTER_CHANCE.
const CHATTER_IDLE_TICKS : int = 30
## Chance, checked once per tick once the passenger has been idle for CHATTER_IDLE_TICKS+ ticks,
## that they'll have a chatter thought.
const CHATTER_CHANCE : float = 0.05

## Flavour lines for idle chatter - "for now" placeholder content, just to keep passengers feeling
## alive between needs/work thoughts.
const CHATTER_LINES : Array[String] = [
	"The train rattles on.",
	"I wonder what's past the next stop.",
	"I'm finally getting used to the track noise.",
	"I should stretch my legs sometime.",
	"Wonder what's for dinner.",
	"How long will we live like this.",
	"I'm lucky to be here I guess."
]

# Recent thought text, most recent last - kept mainly so a passenger's detail panel can show
# "what are they thinking right now" (see get_last_thought_text()).
var thoughts : PackedStringArray = []

# Ticks since this passenger last had a thought of any kind - see tick(). Reset by emit_thought()
# every time it's called, even if the thought itself gets suppressed as a duplicate (dwelling on
# the same thing still isn't "quiet").
var _ticks_since_last_thought : int = 0

# Lazily-built above-head popup - a passenger that never thinks never pays to have one.
var _popup : PanelContainer = null
var _popup_label : Label = null
var _popup_icon : TextureRect = null
var _popup_style : StyleBoxFlat = null
var _popup_timer : Timer = null


func _init(owning_passenger : Passenger) -> void:
	passenger = owning_passenger


## Build, log and show a thought of the given type/sentiment above the passenger's head.
## icon_key selects the popup's icon (see _icon_for_key()) - leave it "" for a thought that
## doesn't have a mapped icon yet, and the popup falls back to showing type as text. Skips a
## thought whose text exactly repeats the passenger's last one, so a condition that's rechecked
## every tick (like a need sitting above its thought threshold) doesn't spam duplicates.
func emit_thought(type : String, sentiment : int, text : String, icon_key : String = "") -> void:
	_ticks_since_last_thought = 0
	if thoughts.size() > 0 and thoughts[thoughts.size() - 1] == text:
		return
	thoughts.append(text)

	var thought : PassengerThought = PassengerThought.new(type, sentiment, text, "%s %s" % [passenger.firstname, passenger.lastname], icon_key)
	_show_popup(thought)
	if Globals.activeUI != null:
		Globals.activeUI.add_passenger_thought(thought)


## Text of the most recent thought this passenger had, or "" if they haven't had one yet.
func get_last_thought_text() -> String:
	if thoughts.size() > 0:
		return thoughts[thoughts.size() - 1]
	return ""


## Called once per resource tick (see Passenger.resource_tick()). Once the passenger has gone
## CHATTER_IDLE_TICKS ticks without any thought (needs, work, or otherwise), rolls a small
## per-tick chance to have them think something idle, just to keep quiet passengers feeling alive.
func tick() -> void:
	_ticks_since_last_thought += 1
	if _ticks_since_last_thought < CHATTER_IDLE_TICKS:
		return
	if randf() < CHATTER_CHANCE:
		_emit_chatter()


func _emit_chatter() -> void:
	var line : String = CHATTER_LINES[randi() % CHATTER_LINES.size()]
	emit_thought(PassengerThought.TYPE_CHATTER, PassengerThought.SENTIMENT_NEUTRAL, line)


func _show_popup(thought : PassengerThought) -> void:
	_ensure_popup_built()
	_popup_style.bg_color = _color_for_sentiment(thought.sentiment)

	var icon : Dictionary = _icon_for_key(thought.icon_key)
	if icon.is_empty():
		_popup_icon.hide()
		_popup_label.text = thought.type
		_popup_label.show()
	else:
		_popup_label.hide()
		_popup_icon.texture = icon["texture"]
		_popup_icon.modulate = icon["modulate"]
		_popup_icon.show()

	_popup.show()
	_popup_timer.start(POPUP_DURATION)


func _color_for_sentiment(sentiment : int) -> Color:
	if sentiment > 0:
		return POPUP_POSITIVE_COLOR
	if sentiment < 0:
		return POPUP_NEGATIVE_COLOR
	return POPUP_NEUTRAL_COLOR


## Icon (texture + modulate) for a thought's icon_key, or {} if that key has no icon mapped yet
## (the popup then falls back to text - see _show_popup()). "For now" this reuses icons from
## other systems where the need and a resource are the same thing (hunger -> food1's icon,
## thirst -> clean_water's icon, both via ResourceTypeRegistry); rest uses the blank placeholder
## texture with a flat grey tint. Swap the textures/colours here (or add more keys) once
## dedicated thought icons exist.
func _icon_for_key(icon_key : String) -> Dictionary:
	match icon_key:
		"hunger":
			return _icon_from_resource_type("food1")
		"thirst":
			return _icon_from_resource_type("clean_water")
		"rest":
			return {"texture": Globals.blank_texture, "modulate": REST_ICON_MODULATE}
	return {}


func _icon_from_resource_type(resource_type_name : String) -> Dictionary:
	var resource_type : ResourceType = ResourceTypeRegistry.get_type(resource_type_name)
	if resource_type == null:
		return {}
	return {"texture": resource_type.iconTexture, "modulate": resource_type.iconModulate}


func _ensure_popup_built() -> void:
	if _popup != null:
		return

	_popup_style = StyleBoxFlat.new()
	_popup_style.bg_color = POPUP_NEUTRAL_COLOR
	_popup_style.corner_radius_top_left = 8
	_popup_style.corner_radius_top_right = 8
	_popup_style.corner_radius_bottom_left = 8
	_popup_style.corner_radius_bottom_right = 8
	_popup_style.content_margin_left = 6
	_popup_style.content_margin_right = 6
	_popup_style.content_margin_top = 2
	_popup_style.content_margin_bottom = 2

	_popup = PanelContainer.new()
	_popup.position = Vector2(-20, -95)
	_popup.custom_minimum_size = Vector2(24, 24)
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_theme_stylebox_override("panel", _popup_style)
	_popup.hide()

	_popup_label = Label.new()
	_popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_label.add_theme_color_override("font_color", Color.WHITE)
	_popup.add_child(_popup_label)

	_popup_icon = TextureRect.new()
	# Source icon textures (from ResourceType/Globals) are much bigger than this popup - IGNORE_SIZE
	# stops the TextureRect reporting the texture's native size as its minimum, so
	# custom_minimum_size actually caps the displayed size instead of just being a floor.
	_popup_icon.custom_minimum_size = Vector2(24, 24)
	_popup_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_popup_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_popup_icon.hide()
	_popup.add_child(_popup_icon)

	passenger.add_child(_popup)

	_popup_timer = Timer.new()
	_popup_timer.one_shot = true
	_popup_timer.timeout.connect(_on_popup_timer_timeout)
	passenger.add_child(_popup_timer)


func _on_popup_timer_timeout() -> void:
	if is_instance_valid(_popup):
		_popup.hide()
