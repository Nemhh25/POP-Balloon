extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("102d43"))
	var center := size * Vector2(0.32, 0.4)
	# Static paper-like rays: no textures, particles, or per-frame updates.
	for ray in 10:
		var angle := ray * TAU / 10.0
		draw_colored_polygon(PackedVector2Array([center, center + Vector2.from_angle(angle) * 1600, center + Vector2.from_angle(angle + 0.19) * 1600]), Color(0.27, 0.65, 0.73, 0.035))
	for i in range(6, 0, -1):
		draw_circle(center, 50.0 + i * 48.0, Color(0.21, 0.37, 0.52, 0.025))
	for i in 28:
		var point := Vector2(fmod(i * 173.0 + 31, size.x), fmod(i * 97.0 + 20, size.y))
		if i % 5 == 0:
			draw_colored_polygon(PackedVector2Array([point + Vector2(0,-6), point + Vector2(2,-2), point + Vector2(6,0), point + Vector2(2,2), point + Vector2(0,6), point + Vector2(-2,2), point + Vector2(-6,0), point + Vector2(-2,-2)]), Color(0.55, 0.82, 0.87, 0.17))
		else:
			draw_circle(point, 2.0, Color(0.62, 0.75, 0.9, 0.12))
