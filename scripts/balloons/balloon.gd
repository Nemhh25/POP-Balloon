class_name Balloon
extends Control

signal clicked
signal damaged(current_health: float, max_health: float, attack_result: AttackResult)
signal popped(balloon_data: BalloonData)

var _data: BalloonData
var _current_health := 1.0
var _max_health := 1.0
var _is_popped := false

func _ready() -> void:
	pivot_offset = size * 0.5
	resized.connect(_on_resized)
	queue_redraw()

func configure(balloon_data: BalloonData, current_health: float, max_health: float) -> void:
	_data = balloon_data
	_max_health = maxf(1.0, max_health)
	_current_health = clampf(current_health, 0.0, _max_health)
	_is_popped = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func take_damage(attack_result: AttackResult) -> void:
	if _is_popped or attack_result.damage <= 0.0:
		return
	_current_health = maxf(0.0, _current_health - attack_result.damage)
	damaged.emit(_current_health, _max_health, attack_result)
	_play_hit_feedback()
	queue_redraw()
	if is_zero_approx(_current_health):
		_is_popped = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		popped.emit(_data)
		_play_pop_feedback()

func _input(event: InputEvent) -> void:
	if _is_popped:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _is_pointer_over_body(event.position):
		# The HUD overlays the play area, so the balloon claims its own visible area
		# before GUI controls can consume the mouse event.
		get_viewport().set_input_as_handled()
		clicked.emit()

func _is_pointer_over_body(viewport_position: Vector2) -> bool:
	var local_position := get_global_transform_with_canvas().affine_inverse() * viewport_position
	var center := Vector2(size.x * 0.5, size.y * 0.44)
	var radius := minf(size.x * 0.36, size.y * 0.34)
	return local_position.distance_squared_to(center) <= radius * radius

func _draw() -> void:
	if _data == null:
		return
	var center := Vector2(size.x * 0.5, size.y * 0.44)
	var radius := minf(size.x * 0.36, size.y * 0.34)
	var color := _data.display_color
	var health_ratio := _current_health / _max_health
	var body_color := color.lerp(Color(0.18, 0.18, 0.24, 1.0), 0.22 * (1.0 - health_ratio))
	draw_circle(center, radius, body_color)
	draw_circle(center - Vector2(radius * 0.22, radius * 0.25), radius * 0.18, Color(1.0, 1.0, 1.0, 0.35))
	draw_line(center + Vector2(0.0, radius), center + Vector2(0.0, radius * 1.62), color.darkened(0.35), 3.0, true)
	draw_circle(center + Vector2(0.0, radius), radius * 0.06, color.darkened(0.3))

func _play_hit_feedback() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.94, 1.06), 0.045)
	tween.tween_property(self, "scale", Vector2.ONE, 0.09)

func _play_pop_feedback() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 0.8), 0.06)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.12)

func _on_resized() -> void:
	pivot_offset = size * 0.5
	queue_redraw()
