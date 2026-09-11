class_name Balloon
extends Control

signal clicked
signal damaged(current_health: float, max_health: float, attack_result: AttackResult)
signal popped(balloon_data: BalloonData)
signal hold_started
signal hold_ended

const AUTO_HIT_FEEDBACK_COOLDOWN_MSEC := 340

@onready var _health_label: Label = %HealthLabel
@onready var _health_bar: ProgressBar = %HealthBar

var _data: BalloonData
var _current_health := 1.0
var _max_health := 1.0
var _is_popped := false
var _hit_tween: Tween
var _health_tween: Tween
var _hovered := false
var _visual_scale := Vector2.ONE
var _highlight := 0.0
var _damage_lag: ProgressBar
var _last_auto_hit_feedback_msec := -AUTO_HIT_FEEDBACK_COOLDOWN_MSEC
var _last_manual_hit_feedback_msec := -AUTO_HIT_FEEDBACK_COOLDOWN_MSEC

func _set_visual_scale(value: Vector2) -> void:
	_visual_scale = value
	queue_redraw()

func _set_highlight(value: float) -> void:
	_highlight = value
	queue_redraw()

func _ready() -> void:
	_health_label.theme_type_variation = "ArcadeTitle"
	_health_bar.custom_minimum_size.y = 8
	_damage_lag = _health_bar.duplicate() as ProgressBar
	_damage_lag.name = "DamageLag"
	add_child(_damage_lag)
	move_child(_damage_lag, _health_bar.get_index())
	# Health presentation must be exact. The former delayed overlay could make
	# the bar look fuller than the HP number during fast manual damage.
	_damage_lag.hide()
	var clear := StyleBoxEmpty.new()
	_health_bar.add_theme_stylebox_override("background", clear)
	var lag_fill := _damage_lag.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	lag_fill.bg_color = Color("ffcf6a")
	_damage_lag.add_theme_stylebox_override("fill", lag_fill)
	pivot_offset = size * 0.5
	resized.connect(_on_resized)
	queue_redraw()

func configure(balloon_data: BalloonData, current_health: float, max_health: float) -> void:
	_data = balloon_data
	_max_health = maxf(1.0, max_health)
	_current_health = clampf(current_health, 0.0, _max_health)
	_is_popped = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_health_label()
	_visual_scale = Vector2(0.9, 0.9)
	_hit_tween = create_tween()
	_hit_tween.tween_method(_set_visual_scale, _visual_scale, Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()

func get_balloon_id() -> StringName:
	return _data.id if _data != null else &""

func get_current_health() -> float:
	return _current_health

func get_max_health() -> float:
	return _max_health

func take_damage(attack_result: AttackResult) -> void:
	if _is_popped or attack_result.damage <= 0.0:
		return
	_current_health = maxf(0.0, _current_health - attack_result.damage)
	_refresh_health_label()
	damaged.emit(_current_health, _max_health, attack_result)
	_play_hit_feedback(attack_result.was_critical, attack_result.is_manual)
	queue_redraw()
	if is_zero_approx(_current_health):
		_is_popped = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		popped.emit(_data)
		_play_pop_feedback()

func _input(event: InputEvent) -> void:
	if _is_popped:
		return
	if event is InputEventMouseMotion:
		var hovering := _is_pointer_over_body(event.position)
		if hovering != _hovered:
			_hovered = hovering
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovering else Control.CURSOR_ARROW
			if _hit_tween: _hit_tween.kill()
			_hit_tween = create_tween().set_parallel(true)
			_hit_tween.tween_method(_set_visual_scale, _visual_scale, Vector2.ONE * (1.035 if hovering else 1.0), 0.12)
			_hit_tween.tween_method(_set_highlight, _highlight, 0.12 if hovering else 0.0, 0.12)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _is_pointer_over_body(event.position):
		# The HUD overlays the play area, so the balloon claims its own visible area
		# before GUI controls can consume the mouse event.
		get_viewport().set_input_as_handled()
		clicked.emit()
		hold_started.emit()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		hold_ended.emit()

func _is_pointer_over_body(viewport_position: Vector2) -> bool:
	var local_position := get_global_transform_with_canvas().affine_inverse() * viewport_position
	var center := Vector2(size.x * 0.5, size.y * 0.47)
	var radius := minf(size.x * 0.34, size.y * 0.28) * 1.12
	return local_position.distance_squared_to(center) <= radius * radius

func _draw() -> void:
	if _data == null:
		return
	var center := Vector2(size.x * 0.5, size.y * 0.47)
	var radius := minf(size.x * 0.34, size.y * 0.28) * 1.12
	draw_set_transform(center, 0.0, _visual_scale)
	center = Vector2.ZERO
	var color := _data.display_color
	var health_ratio := _current_health / _max_health
	var body_color := color.lerp(Color(0.18, 0.18, 0.24, 1.0), 0.22 * (1.0 - health_ratio)).lightened(_highlight)
	draw_circle(center + Vector2(0, 4), radius + 3, Color("10182b"))
	if _data.id == &"rainbow_balloon":
		# Static color wedges read as rainbow immediately without a flashing effect.
		for slice in 7:
			var points := PackedVector2Array([center])
			var start_angle := -PI * 0.5 + slice * TAU / 7.0
			for step in 7:
				var angle := start_angle + step * (TAU / 7.0) / 6.0
				points.append(center + Vector2.from_angle(angle) * radius)
			var rainbow_color := Color.from_hsv(float(slice) / 7.0, 0.72, 0.98)
			rainbow_color = rainbow_color.lerp(Color(0.18, 0.18, 0.24), 0.22 * (1.0 - health_ratio)).lightened(_highlight)
			draw_colored_polygon(points, rainbow_color)
	else:
		draw_circle(center, radius, body_color)
	draw_arc(center, radius, 0, TAU, 64, Color("10182b"), 4.0, true)
	# Rainbow wedges already supply their own shading. A single colored crescent
	# here reads as an unwanted leftover progress bar on its lower edge.
	if _data.id != &"rainbow_balloon":
		draw_arc(center, radius * 0.88, 0.3, 2.5, 40, color.darkened(0.28), 7.0, true)
	draw_arc(center, radius * 0.84, 3.65, 4.48, 20, Color(1, 1, 1, 0.7), 5.0, true)
	if _data.category == BalloonData.Category.SPECIAL:
		draw_arc(center, radius * 1.05, 0.0, TAU, 40, Color(1.0, 0.88, 0.3, 0.95), 3.0, true)
	draw_circle(center - Vector2(radius * 0.22, radius * 0.25), radius * 0.18, Color(1.0, 1.0, 1.0, 0.35))
	var knot := center + Vector2(0.0, radius)
	var string_end := center + Vector2(0.0, radius * 1.82)
	# A double stroke keeps the string readable against every balloon tier and the stage.
	draw_line(knot, string_end, Color("0b1224"), 6.0, true)
	draw_line(knot, string_end, Color("ffd36a").lerp(color.lightened(0.18), 0.38), 2.6, true)
	draw_circle(knot, radius * 0.085, Color("10182b"))
	draw_circle(knot, radius * 0.055, color.lightened(0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(-9, radius + 10), Vector2(0, radius - 2), Vector2(9, radius + 10)]), Color("10182b"))
	draw_colored_polygon(PackedVector2Array([Vector2(-6, radius + 8), Vector2(0, radius), Vector2(6, radius + 8)]), color.darkened(0.08))

func _play_hit_feedback(was_critical: bool, is_manual: bool) -> void:
	var now := Time.get_ticks_msec()
	if not is_manual:
		if now - _last_auto_hit_feedback_msec < AUTO_HIT_FEEDBACK_COOLDOWN_MSEC or now - _last_manual_hit_feedback_msec < 180:
			return
		_last_auto_hit_feedback_msec = now
		if _hit_tween: _hit_tween.kill()
		var idle := Vector2.ONE * (1.035 if _hovered else 1.0)
		_set_visual_scale(idle * Vector2(1.008, 0.988))
		_set_highlight(0.06)
		_hit_tween = create_tween().set_parallel(true)
		_hit_tween.tween_method(_set_visual_scale, _visual_scale, idle, 0.12)
		_hit_tween.tween_method(_set_highlight, _highlight, 0.0, 0.12)
		return
	_last_manual_hit_feedback_msec = now
	if _hit_tween: _hit_tween.kill()
	_set_visual_scale(Vector2(1.06, 0.90) if was_critical else Vector2(1.03, 0.92))
	_set_highlight(0.40 if was_critical else 0.14)
	_hit_tween = create_tween()
	_hit_tween.tween_method(_set_visual_scale, _visual_scale, Vector2(0.97, 1.04), 0.07)
	_hit_tween.tween_method(_set_visual_scale, Vector2(0.97, 1.04), Vector2.ONE * (1.035 if _hovered else 1.0), 0.12)
	_hit_tween.parallel().tween_method(_set_highlight, _highlight, 0.12 if _hovered else 0.0, 0.12)

func _play_pop_feedback() -> void:
	if _hit_tween: _hit_tween.kill()
	_health_bar.value = 0.0
	_damage_lag.value = 0.0
	# Keep HP 0 visible briefly before the pop fade so number and bar agree.
	_hit_tween = create_tween()
	_hit_tween.tween_interval(0.035)
	_hit_tween.set_parallel(true)
	_hit_tween.tween_method(_set_visual_scale, _visual_scale, Vector2(1.18, 1.18), 0.095)
	_hit_tween.tween_property(self, "modulate:a", 0.0, 0.095)

func _on_resized() -> void:
	pivot_offset = size * 0.5
	queue_redraw()

func _refresh_health_label() -> void:
	if is_instance_valid(_health_label):
		_health_label.text = "HP  %s / %s" % [preload("res://scripts/ui/number_format.gd").compact(ceilf(_current_health)), preload("res://scripts/ui/number_format.gd").compact(ceilf(_max_health))]
	if is_instance_valid(_health_bar):
		if _health_tween: _health_tween.kill()
		_health_bar.max_value = _max_health
		_damage_lag.max_value = _max_health
		if _data != null:
			var fill := _health_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
			fill.bg_color = Color("ff937d") if _current_health / _max_health <= 0.2 else _data.display_color.lightened(0.45)
			_health_bar.add_theme_stylebox_override("fill", fill)
		_health_bar.value = _current_health
		_damage_lag.value = _current_health
