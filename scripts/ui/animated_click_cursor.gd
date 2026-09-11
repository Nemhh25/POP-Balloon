class_name AnimatedClickCursor
extends Control

# One software cursor while hovering/pressing the balloon; native cursor elsewhere.
const ICON_SHEET: Texture2D = preload("res://assets/ui/sprites/upgrade_icons.png")
const CURSOR_SIZE := Vector2(42, 42)
const HOTSPOT := Vector2(13, 7)

var _session: GameSession
var _hud: MainHud
var _fade: Control
var _sprite: TextureRect
var _press_tween: Tween
var _owns_mouse := false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _suspended := false
var _pointer_position := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer_position = get_viewport().get_mouse_position()
	var source := ICON_SHEET.get_image()
	var cell := Vector2i(source.get_width() / 4, source.get_height() / 4)
	var hand := source.get_region(Rect2i(Vector2i.ZERO, cell))
	hand.resize(int(CURSOR_SIZE.x), int(CURSOR_SIZE.y), Image.INTERPOLATE_LANCZOS)
	var texture := ImageTexture.create_from_image(hand)
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_POINTING_HAND, HOTSPOT)
	_sprite = TextureRect.new()
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.texture = texture
	_sprite.size = CURSOR_SIZE
	_sprite.position = -HOTSPOT
	_sprite.pivot_offset = HOTSPOT
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sprite)
	_sprite.hide()

func setup(session: GameSession, hud: MainHud, fade: Control) -> void:
	_session = session
	_hud = hud
	_fade = fade
	_session._balloon_controller.balloon_damaged.connect(_on_damage)
	_session._balloon_controller._container.child_entered_tree.connect(_on_target_changed)
	for overlay: Control in [_hud._pause_overlay, _hud._victory_overlay, _hud._audio_settings_panel, _fade]:
		overlay.visibility_changed.connect(_on_visibility_changed)

func _process(_delta: float) -> void:
	# Pointer tracking is the only per-frame job; animation itself uses one bounded Tween.
	_update_pointer()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_pointer_position = event.position
		# Restore the native cursor immediately when the pointer leaves the balloon.
		_update_pointer()

func _update_pointer(valid_hit: bool = false) -> void:
	if _session == null or _blocked():
		reset()
		return
	global_position = get_canvas_transform().affine_inverse() * _pointer_position
	var balloon := _session._balloon_controller._current_balloon
	var over_body := is_instance_valid(balloon) and balloon._is_pointer_over_body(_pointer_position)
	var hover := get_viewport().gui_get_hovered_control()
	var over_ui := hover != null and is_instance_valid(balloon) and hover != balloon and not balloon.is_ancestor_of(hover) and not hover.is_ancestor_of(balloon)
	var pressing := _press_tween != null and _press_tween.is_running()
	if not over_body or over_ui or (balloon.get_current_health() <= 0.0 and not pressing and not valid_hit):
		reset()
		return
	if not _owns_mouse:
		_previous_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		_owns_mouse = true
	_sprite.show()
	if not pressing:
		_sprite.position = -HOTSPOT
		_sprite.rotation = 0.0
		_sprite.scale = Vector2.ONE * 1.03

func _on_damage(_health: float, _maximum: float, attack: AttackResult) -> void:
	if not attack.is_manual or attack.damage <= 0.0 or _blocked():
		return
	_update_pointer(true)
	if not _sprite.visible or (_press_tween != null and _press_tween.is_running()):
		return
	_sprite.position = -HOTSPOT
	_sprite.rotation = 0.0
	_sprite.scale = Vector2.ONE
	_press_tween = create_tween()
	_press_tween.tween_property(_sprite, "position", -HOTSPOT + Vector2(2, 8), 0.025).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_press_tween.parallel().tween_property(_sprite, "rotation", -0.14, 0.025)
	_press_tween.parallel().tween_property(_sprite, "scale", Vector2(0.96, 0.93), 0.025)
	# A two-frame contact at 60fps remains visible even during rapid clicks.
	_press_tween.tween_interval(0.025)
	_press_tween.tween_property(_sprite, "position", -HOTSPOT, 0.055).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_press_tween.parallel().tween_property(_sprite, "rotation", 0.0, 0.055)
	_press_tween.parallel().tween_property(_sprite, "scale", Vector2.ONE * 1.03, 0.055)

func _blocked() -> bool:
	var statistics_open := _hud._statistics_panel != null and _hud._statistics_panel.visible
	return _suspended or not is_visible_in_tree() or get_tree().paused or _hud._victory_overlay.visible or _hud._pause_overlay.visible or _hud._audio_settings_panel.visible or statistics_open or _fade.visible

func _on_visibility_changed() -> void:
	if _blocked():
		reset()

func _on_target_changed(node: Node) -> void:
	if node is Balloon:
		reset()

func reset() -> void:
	if _press_tween != null:
		_press_tween.kill()
		_press_tween = null
	if is_instance_valid(_sprite):
		_sprite.hide()
		_sprite.position = -HOTSPOT
		_sprite.rotation = 0.0
		_sprite.scale = Vector2.ONE
	if _owns_mouse:
		Input.mouse_mode = _previous_mouse_mode
		_owns_mouse = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_WM_MOUSE_EXIT:
		_suspended = true
		reset()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN or what == NOTIFICATION_WM_MOUSE_ENTER:
		_suspended = false

func _exit_tree() -> void:
	reset()
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
