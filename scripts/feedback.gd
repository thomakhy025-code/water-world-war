extends RefCounted

const Floater = preload("res://scripts/floater.gd")


static func rising_text(parent: Node, at: Vector2, text: String, color: Color) -> void:
	var label = Floater.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	parent.add_child(label)
	label.global_position = at
