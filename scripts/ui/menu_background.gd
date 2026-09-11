class_name MenuBackground
extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("102d43"))
	var center := size * Vector2(0.5, 0.42)
	for ray in 12:
		var angle := ray * TAU / 12.0
		draw_colored_polygon(PackedVector2Array([center, center + Vector2.from_angle(angle) * 1500.0, center + Vector2.from_angle(angle + 0.16) * 1500.0]), Color(0.28, 0.72, 0.78, 0.045))
	for index in 20:
		var point := Vector2(fmod(index * 181.0 + 50.0, maxf(size.x, 1.0)), fmod(index * 113.0 + 28.0, maxf(size.y, 1.0)))
		draw_circle(point, 2.0 + float(index % 3), Color(0.7, 0.92, 0.98, 0.12))

