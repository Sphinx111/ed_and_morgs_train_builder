extends RefCounted
class_name NarrativeEventLoader

const EVENTS_PATH: String = "res://DialogData/events.csv"
const PROMPTS_PATH: String = "res://DialogData/prompts.csv"
const CHOICES_PATH: String = "res://DialogData/choices.csv"

static var _events: Dictionary = {}
static var _loaded: bool = false


static func load_all() -> Dictionary:
	_events.clear()
	_load_events()
	_load_prompts()
	_load_choices()
	_loaded = true
	return _events


static func get_event(event_key: String) -> NarrativeEvent:
	if not _loaded:
		load_all()
	return _events.get(event_key)


static func _load_events() -> void:
	var file: FileAccess = FileAccess.open(EVENTS_PATH, FileAccess.READ)
	if file == null:
		push_error("NarrativeEventLoader: could not open %s" % EVENTS_PATH)
		return

	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.is_empty() or row[0] == "":
			continue

		var event: NarrativeEvent = NarrativeEvent.new()
		event.eventName = row[0]
		event.id = row[1].to_int()
		event.stepsCount = row[2].to_int()
		event.choicesCount = row[3].to_int()
		event.sequence = _parse_sequence(row[4])
		event.promptTexts = []
		event.choicesDict = {}
		_events[event.eventName] = event


static func _load_prompts() -> void:
	var file: FileAccess = FileAccess.open(PROMPTS_PATH, FileAccess.READ)
	if file == null:
		push_error("NarrativeEventLoader: could not open %s" % PROMPTS_PATH)
		return

	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.is_empty() or row[0] == "":
			continue

		var event: NarrativeEvent = _events.get(row[0])
		if event == null:
			push_warning("NarrativeEventLoader: unknown event in prompts.csv: %s" % row[0])
			continue

		var step_index: int = row[1].to_int()
		_ensure_array_size(event.promptTexts, step_index + 1, "")
		event.promptTexts[step_index] = row[2]


static func _load_choices() -> void:
	var file: FileAccess = FileAccess.open(CHOICES_PATH, FileAccess.READ)
	if file == null:
		push_error("NarrativeEventLoader: could not open %s" % CHOICES_PATH)
		return

	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.is_empty() or row[0] == "":
			continue

		var event: NarrativeEvent = _events.get(row[0])
		if event == null:
			push_warning("NarrativeEventLoader: unknown event in choices.csv: %s" % row[0])
			continue

		var choice_index: int = row[1].to_int()
		var train_event: TrainEvent = _parse_train_event(row[4], row[5], row[6])
		var next_event_key: String = row[7] if row.size() > 7 else ""
		var min_delay: float = _parse_min_delay(row[8] if row.size() > 8 else "")
		event.choicesDict[choice_index] = [row[2], row[3], train_event, next_event_key, min_delay]


static func _parse_sequence(raw: String) -> Array[int]:
	var result: Array[int] = []
	for part: String in raw.split("|", false):
		result.append(part.to_int())
	return result


static func _parse_train_event(type_name: String, var1_raw: String, var2_raw: String) -> TrainEvent:
	var event_type: int = _parse_event_type(type_name)
	return TrainEvent.new(event_type, _parse_variant(var1_raw), _parse_variant(var2_raw))


static func _parse_event_type(type_name: String) -> int:
	match type_name:
		"NO_EFFECT":
			return TrainEvent.NO_EFFECT
		"CHANGE_RESOURCE":
			return TrainEvent.CHANGE_RESOURCE
		"CHANGE_MOOD":
			return TrainEvent.CHANGE_MOOD
		"CHANGE_POP":
			return TrainEvent.CHANGE_POP
		_:
			push_warning("NarrativeEventLoader: unknown TrainEvent type: %s" % type_name)
			return TrainEvent.NO_EFFECT


static func _parse_min_delay(raw: String) -> float:
	if raw == "":
		return 0.0
	if raw.is_valid_float():
		return raw.to_float()
	if raw.is_valid_int():
		return float(raw.to_int())
	push_warning("NarrativeEventLoader: invalid min_delay value: %s" % raw)
	return 0.0


static func _parse_variant(raw: String) -> Variant:
	if raw == "":
		return null
	if raw.is_valid_int():
		return raw.to_int()
	if raw.is_valid_float():
		return raw.to_float()
	return raw


static func _ensure_array_size(array: Array, size: int, default: Variant) -> void:
	while array.size() < size:
		array.append(default)
