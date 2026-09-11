class_name BalloonVisualEffects
extends Control

# Presentation-only equipment attacks. Combat remains owned by GameSession.
const ICON_SHEET: Texture2D = preload("res://assets/ui/sprites/upgrade_icons.png")
const PROJECTILE_POOL_SIZE := 4
const MAX_SIMULTANEOUS_ATTACKERS := 2
const VISUAL_HIT_INTERVAL := 0.34
const SPRITE_TIP_ANGLE := 3.0 * PI / 4.0 # Needle/Dart artwork points down-left.

const EQUIPMENT_SLOTS := {
	&"needle": Vector2(-0.95, -0.42),
	&"dart": Vector2(0.95, -0.42),
	# On the right it keeps its native left-facing barrel aimed at the balloon.
	&"dart_launcher": Vector2(1.08, 0.08),
	&"pressure_gun": Vector2(0.78, 0.73),
	&"balloon_popping_machine": Vector2(-0.78, 0.73),
	&"popbot": Vector2(-1.05, 0.08),
	&"anti_balloon_cannon": Vector2(-0.42, 0.91),
}

var _session: GameSession
var _effects: Array[Dictionary] = []
var _projectile_pool: Array[TextureRect] = []
var _active_projectiles: Array[Dictionary] = []
var _attack_throttle: Timer
var _attack_cursor := 0
var _textures: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout_equipment_slots)
	_create_projectile_pool()
	_attack_throttle = Timer.new()
	_attack_throttle.one_shot = true
	_attack_throttle.wait_time = VISUAL_HIT_INTERVAL
	add_child(_attack_throttle)

func setup(session: GameSession) -> void:
	_session = session
	_session.equipment_presentation_changed.connect(refresh)
	_session.auto_attack_performed.connect(_on_auto_attack_performed)
	var controller := _session._balloon_controller
	controller.balloon_damaged.connect(_on_balloon_damaged)
	controller.balloon_popped.connect(func(_data: BalloonData) -> void: _reset_animations())
	controller.special_balloon_popped.connect(func(_data: BalloonData) -> void: _reset_animations())
	controller.boss_balloon_popped.connect(func(_data: BalloonData) -> void: _reset_animations())
	controller._container.child_entered_tree.connect(_on_balloon_replaced)
	controller._container.child_exiting_tree.connect(_on_balloon_removed)
	refresh()

func refresh() -> void:
	if _session == null:
		return
	var owned: Array[StringName] = []
	for id: StringName in EQUIPMENT_SLOTS:
		if _session.get_equipment_level(id) > 0:
			owned.append(id)
	var displayed: Array[StringName] = []
	for effect: Dictionary in _effects:
		displayed.append(effect.id)
	if owned == displayed:
		return # Level/stat refreshes must not rebuild sprites or restart attacks.
	_reset_animations()
	for effect: Dictionary in _effects:
		var node := effect["node"] as TextureRect
		if is_instance_valid(node):
			node.queue_free()
	_effects.clear()
	if _session == null:
		return
	# Only owned automatic equipment is represented in the play field.
	_add_equipment(&"needle", Vector2i(2, 1), 36.0)
	_add_equipment(&"dart", Vector2i(3, 1), 40.0)
	_add_equipment(&"dart_launcher", Vector2i(0, 2), 44.0)
	_add_equipment(&"pressure_gun", Vector2i(1, 2), 44.0)
	_add_equipment(&"balloon_popping_machine", Vector2i(2, 2), 48.0)
	_add_equipment(&"popbot", Vector2i(3, 2), 48.0)
	_add_equipment(&"anti_balloon_cannon", Vector2i(0, 3), 50.0)
	_layout_equipment_slots.call_deferred()

func _add_equipment(id: StringName, icon_cell: Vector2i, icon_size: float) -> void:
	if _session.get_equipment_level(id) <= 0:
		return
	var icon := TextureRect.new()
	# Set expand mode before texture/size: otherwise the atlas forces a 313px minimum.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture = _sheet_icon(icon_cell)
	icon.custom_minimum_size = Vector2.ONE * icon_size
	icon.size = icon.custom_minimum_size
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.pivot_offset = icon.size * 0.5
	add_child(icon)
	_effects.append({
		"id": id,
		"node": icon,
		"slot": EQUIPMENT_SLOTS[id],
		"rest_position": Vector2.ZERO,
		"rest_rotation": 0.0,
		"attack_tween": null,
	})

func _layout_equipment_slots() -> void:
	_reset_animations()
	var center := _get_balloon_center()
	var balloon := _session._balloon_controller._current_balloon if _session != null else null
	var health_bottom := -INF
	if is_instance_valid(balloon):
		# The icons may be large, but never consume the local HP readout above it.
		var health_rect := balloon._health_bar.get_global_rect()
		health_bottom = (get_global_transform_with_canvas().affine_inverse() * health_rect.get_center()).y
		health_bottom += health_rect.size.y * 0.5
	for effect: Dictionary in _effects:
		var icon := effect["node"] as TextureRect
		if not is_instance_valid(icon):
			continue
		var slot: Vector2 = effect["slot"]
		var slot_radius := _get_balloon_radius() + icon.size.length() * 0.5 + 12.0
		var position := center + slot.normalized() * slot_radius - icon.size * 0.5
		var icon_half := icon.size * 0.5
		var icon_center := position + icon_half
		var minimum_center_y := health_bottom + 10.0 + icon_half.y
		icon_center.y = maxf(icon_center.y, minimum_center_y)
		# Reproject any icon moved down for HP clearance onto the outside orbit.
		# This prevents a larger sprite from clipping back into the balloon body.
		var relative := icon_center - center
		if relative.length() < slot_radius:
			var horizontal_sign := signf(relative.x)
			if is_zero_approx(horizontal_sign):
				horizontal_sign = signf(slot.x)
			var horizontal_distance := sqrt(maxf(0.0, slot_radius * slot_radius - relative.y * relative.y))
			relative.x = horizontal_sign * horizontal_distance
			icon_center = center + relative
		position = icon_center - icon_half
		effect["rest_position"] = position
		var direction := (center - (position + icon.size * 0.5)).normalized()
		effect["rest_rotation"] = direction.angle() - SPRITE_TIP_ANGLE if _is_stab_weapon(StringName(effect["id"])) else 0.0
		# Guns in the atlas face left; mirror those on the left to face the target.
		icon.flip_h = slot.x < 0.0 and StringName(effect.id) in [&"pressure_gun", &"dart_launcher", &"anti_balloon_cannon", &"popbot"]
		if not _is_effect_attacking(effect):
			_restore_effect(effect)

func _on_balloon_damaged(health: float, _maximum: float, attack: AttackResult) -> void:
	# This signal is emitted only while an active balloon receives damage. The
	# previous Control processing/visibility guards could be false during layout
	# and silently suppress every equipment animation.
	if health <= 0.0 or attack.is_manual or attack.damage <= 0.0 or not _attack_throttle.is_stopped():
		return
	_on_auto_attack_performed()

func _on_auto_attack_performed() -> void:
	if _effects.is_empty() or not _attack_throttle.is_stopped():
		return
	_attack_throttle.start()
	_play_automatic_attack()

func _play_automatic_attack() -> void:
	if _effects.is_empty():
		return
	var attack_count := mini(MAX_SIMULTANEOUS_ATTACKERS, _effects.size())
	for offset in attack_count:
		var index := (_attack_cursor + offset) % _effects.size()
		if not _is_effect_attacking(_effects[index]):
			_animate_equipment(_effects[index], offset * 0.025)
	_attack_cursor = (_attack_cursor + attack_count) % _effects.size()

func _animate_equipment(effect: Dictionary, delay: float) -> void:
	var id := StringName(effect["id"])
	match id:
		&"needle", &"dart": _animate_stab(effect, delay)
		&"popbot": _animate_popbot(effect, delay)
		_: _animate_launcher(effect, delay)

func _animate_stab(effect: Dictionary, delay: float) -> void:
	var icon := effect["node"] as TextureRect
	var rest := effect["rest_position"] as Vector2
	var center := _get_balloon_center()
	var outward := (rest + icon.size * 0.5 - center).normalized()
	var impact := center + outward * (_get_balloon_radius() + icon.size.x * 0.46) - icon.size * 0.5
	var overshoot := impact - outward * 4.0
	var tween := _begin_attack_tween(effect, delay)
	tween.tween_property(icon, "position", impact, 0.075).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(icon, "scale", Vector2(1.04, 0.97), 0.075)
	tween.tween_property(icon, "position", overshoot, 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(icon, "scale", Vector2(0.98, 1.03), 0.045)
	tween.tween_property(icon, "position", rest, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(icon, "scale", Vector2.ONE, 0.13)
	tween.tween_callback(func() -> void: _finish_attack(effect))

func _animate_launcher(effect: Dictionary, delay: float) -> void:
	var icon := effect["node"] as TextureRect
	var rest := effect["rest_position"] as Vector2
	var center := _get_balloon_center()
	var outward := (rest + icon.size * 0.5 - center).normalized()
	var recoil := rest + outward * (5.0 if effect.id == &"anti_balloon_cannon" else 3.0)
	var tween := _begin_attack_tween(effect, delay)
	tween.tween_property(icon, "position", recoil, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(icon, "scale", Vector2(0.95, 1.04), 0.06)
	tween.tween_callback(func() -> void: _launch_projectile(effect))
	tween.tween_property(icon, "position", rest, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(icon, "scale", Vector2.ONE, 0.12)
	tween.tween_callback(func() -> void: _finish_attack(effect))

func _animate_popbot(effect: Dictionary, delay: float) -> void:
	var icon := effect["node"] as TextureRect
	var rest := effect["rest_position"] as Vector2
	var center := _get_balloon_center()
	var outward := (rest + icon.size * 0.5 - center).normalized()
	var approach := rest - outward * 7.0
	var tween := _begin_attack_tween(effect, delay)
	tween.tween_property(icon, "position", approach, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(icon, "scale", Vector2(1.04, 0.97), 0.10)
	tween.tween_callback(func() -> void: _launch_projectile(effect, true))
	tween.tween_property(icon, "position", rest, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(icon, "scale", Vector2.ONE, 0.15)
	tween.tween_callback(func() -> void: _finish_attack(effect))

func _begin_attack_tween(effect: Dictionary, delay: float) -> Tween:
	var existing := _get_attack_tween(effect)
	if existing != null and existing.is_valid():
		existing.kill()
		_restore_effect(effect)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	if delay > 0.0:
		tween.tween_interval(delay)
	_set_attack_tween(effect, tween)
	return tween

func _launch_projectile(effect: Dictionary, from_popbot: bool = false) -> void:
	var projectile := _get_available_projectile()
	if projectile == null:
		return
	var icon := effect["node"] as TextureRect
	var outward := (icon.position + icon.size * 0.5 - _get_balloon_center()).normalized()
	var origin := icon.position + icon.size * 0.5 - outward * icon.size.x * 0.35
	var target := _get_balloon_center() + outward * (_get_balloon_radius() + 1.0)
	projectile.texture = _sheet_icon(Vector2i(2, 1)) if from_popbot else _get_projectile_texture(StringName(effect["id"]))
	projectile.modulate = Color.WHITE
	projectile.position = origin - projectile.size * 0.5
	projectile.rotation = (target - origin).angle() - SPRITE_TIP_ANGLE
	projectile.set_meta("in_use", true)
	projectile.show()
	var tween := create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	tween.tween_property(projectile, "position", target - projectile.size * 0.5, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(projectile, "modulate:a", 0.0, 0.04).set_delay(0.10)
	_active_projectiles.append({"node": projectile, "tween": tween})
	tween.chain().tween_callback(func() -> void: _release_projectile(projectile))

func _create_projectile_pool() -> void:
	for _index in PROJECTILE_POOL_SIZE:
		var projectile := TextureRect.new()
		projectile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		projectile.custom_minimum_size = Vector2(12.0, 12.0)
		projectile.size = projectile.custom_minimum_size
		projectile.pivot_offset = projectile.size * 0.5
		projectile.z_index = 1
		projectile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		projectile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		projectile.hide()
		add_child(projectile)
		_projectile_pool.append(projectile)

func _get_available_projectile() -> TextureRect:
	for projectile in _projectile_pool:
		if not bool(projectile.get_meta("in_use", false)):
			return projectile
	return null

func _release_projectile(projectile: TextureRect) -> void:
	if not is_instance_valid(projectile):
		return
	projectile.hide()
	projectile.remove_meta("in_use")
	for index in range(_active_projectiles.size() - 1, -1, -1):
		if _active_projectiles[index]["node"] == projectile:
			_active_projectiles.remove_at(index)

func _reset_animations() -> void:
	for index in _effects.size():
		var effect := _effects[index]
		var tween := _get_attack_tween(effect)
		_set_attack_tween(effect, null)
		if tween != null and tween.is_valid():
			tween.kill()
		_restore_effect(effect)
	for projectile_data: Dictionary in _active_projectiles.duplicate():
		var tween := projectile_data["tween"] as Tween
		if tween != null and tween.is_valid():
			tween.kill()
		_release_projectile(projectile_data["node"] as TextureRect)
	_active_projectiles.clear()

func _finish_attack(effect: Dictionary) -> void:
	_set_attack_tween(effect, null)
	_restore_effect(effect)

func _on_balloon_replaced(node: Node) -> void:
	if node is Balloon:
		_layout_equipment_slots.call_deferred()

func _on_balloon_removed(node: Node) -> void:
	if node is Balloon:
		_reset_animations()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		_reset_animations()

func _restore_effect(effect: Dictionary) -> void:
	var icon := effect.get("node") as TextureRect
	if not is_instance_valid(icon):
		return
	icon.position = effect.get("rest_position", Vector2.ZERO) as Vector2
	icon.rotation = float(effect.get("rest_rotation", 0.0))
	icon.scale = Vector2.ONE

func _is_effect_attacking(effect: Dictionary) -> bool:
	var tween := _get_attack_tween(effect)
	return tween != null and tween.is_valid() and tween.is_running()

func _get_attack_tween(effect: Dictionary) -> Tween:
	var node := effect.get("node") as TextureRect
	for stored: Dictionary in _effects:
		if stored.get("node") == node:
			return stored.get("attack_tween") as Tween
	return effect.get("attack_tween") as Tween

func _set_attack_tween(effect: Dictionary, tween: Tween) -> void:
	var node := effect.get("node") as TextureRect
	for index in _effects.size():
		var stored := _effects[index]
		if stored.get("node") == node:
			stored["attack_tween"] = tween
			_effects[index] = stored
			return

func _is_stab_weapon(id: StringName) -> bool:
	return id in [&"needle", &"dart"]

func _get_balloon_center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.47)

func _get_balloon_radius() -> float:
	return minf(size.x * 0.34, size.y * 0.28) * 1.12

func _get_projectile_texture(equipment_id: StringName) -> Texture2D:
	return _sheet_icon(Vector2i(3, 1)) if equipment_id == &"dart_launcher" else _sheet_icon(Vector2i(2, 1))

func _sheet_icon(cell: Vector2i) -> AtlasTexture:
	if _textures.has(cell):
		return _textures[cell]
	var sheet_size := ICON_SHEET.get_size()
	var cell_size := sheet_size / 4.0
	var icon := AtlasTexture.new()
	icon.atlas = ICON_SHEET
	icon.region = Rect2(Vector2(cell) * cell_size, cell_size)
	icon.filter_clip = true
	_textures[cell] = icon
	return icon
