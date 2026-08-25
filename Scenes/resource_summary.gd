extends Panel

class_name ResourceSummary


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	$RichTextLabel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(resource_type: ResourceType, amount: float, use_multiplier_prefix: bool = true) -> void:
	$IconSprite.texture = resource_type.iconTexture
	$IconSprite.modulate = resource_type.iconModulate
	var amount_text := ResourceTypeRegistry.format_amount(resource_type.type_name, amount)
	$RichTextLabel.text = ("x%s" % amount_text) if use_multiplier_prefix else amount_text


func setup_by_type_name(type_name: String, amount: float, use_multiplier_prefix: bool = true) -> void:
	var resource_type := ResourceTypeRegistry.get_type(type_name)
	if resource_type == null:
		return
	setup(resource_type, amount, use_multiplier_prefix)
