class_name MenuBalloon
extends Control

@export var balloon_color := Color("ef3650")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var body_size := Vector2(minf(size.x, size.y * 0.76), minf(size.x, size.y * 0.76))
	var radius := body_size.x * 0.5
	var center := Vector2(size.x * 0.5, radius)
	draw_circle(center + Vector2(3.0, 5.0), radius + 3.0, Color("10182b"))
	draw_circle(center, radius, balloon_color)
	draw_circle(center - Vector2(radius * 0.24, radius * 0.22), radius * 0.14, Color(1.0, 1.0, 1.0, 0.35))
	var knot := Vector2(center.x, center.y + radius)
	draw_colored_polygon(PackedVector2Array([knot + Vector2(-7, -1), knot + Vector2(7, -1), knot + Vector2(0, 9)]), Color("10182b"))
	draw_line(knot + Vector2(0, 7), Vector2(center.x, size.y), Color("10182b"), 3.0)
