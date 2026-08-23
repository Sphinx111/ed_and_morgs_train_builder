extends Panel

class_name ResourceSummary


func setup(resource_type: ResourceType, amount: float) -> void:
	$IconSprite.texture = resource_type.iconTexture
	$IconSprite.modulate = resource_type.iconModulate
	$RichTextLabel.text = "x%s" % ResourceTypeRegistry.format_amount(resource_type.type_name, amount)
