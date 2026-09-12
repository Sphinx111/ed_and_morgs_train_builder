extends Node

## Data container for a single thought a passenger had - what kind of thought it was, whether it
## reads as positive/neutral/negative, the thought's own text, and who had it. Built and emitted
## by a passenger's ThoughtsModule (see that file): the ThoughtsModule uses the sentiment to
## colour its above-the-head popup, and the global thoughts panel (TrainUI.add_passenger_thought)
## just shows passenger_name + text for any thought it catches, with no colour coding.
class_name PassengerThought

## Broad category of thought - what prompted it. Effectively an enum for the class, same pattern
## as TrainEvent's eventType constants.
const TYPE_NEEDS : String = "needs"
const TYPE_CHATTER : String = "chatter"
const TYPE_WORK : String = "work"

## How the thought reads to the player.
const SENTIMENT_POSITIVE : int = 1
const SENTIMENT_NEUTRAL : int = 0
const SENTIMENT_NEGATIVE : int = -1

var type : String = TYPE_CHATTER
var sentiment : int = SENTIMENT_NEUTRAL
var text : String = ""
var passenger_name : String = ""

## Which icon the above-head popup should show for this thought (e.g. "hunger", "thirst",
## "rest") - finer-grained than type, since "needs" alone doesn't say which need. "" means the
## popup has no icon mapped yet and should fall back to showing the type as text - see
## ThoughtsModule._icon_for_key().
var icon_key : String = ""


func _init(thought_type : String = TYPE_CHATTER, thought_sentiment : int = SENTIMENT_NEUTRAL, thought_text : String = "", speaker_name : String = "", thought_icon_key : String = "") -> void:
	type = thought_type
	sentiment = thought_sentiment
	text = thought_text
	passenger_name = speaker_name
	icon_key = thought_icon_key
