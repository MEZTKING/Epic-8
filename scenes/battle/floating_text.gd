class_name FloatingText
extends Label
## A number or word that rises and fades above a unit card.


static func spawn(parent: Control, at: Vector2, text: String, color: Color, speed: float, size := 22) -> void:
	var l := FloatingText.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_font_size_override("font_size", size)
	l.position = at
	l.z_index = 10
	parent.add_child(l)
	var tween := l.create_tween()
	tween.set_parallel(true)
	tween.tween_property(l, "position:y", at.y - 48.0, 0.7 / speed)
	tween.tween_property(l, "modulate:a", 0.0, 0.7 / speed).set_delay(0.3 / speed)
	tween.chain().tween_callback(l.queue_free)
