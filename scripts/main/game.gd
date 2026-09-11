class_name Game
extends Control

@export var content_catalog: ContentCatalogData
@export var balloon_scene: PackedScene

const BalloonVisualEffects = preload("res://scripts/ui/balloon_visual_effects.gd")
const ClickCursor = preload("res://scripts/ui/animated_click_cursor.gd")

@onready var _game_session: GameSession = %GameSession
@onready var _balloon_container: Control = %BalloonContainer
@onready var _main_hud: MainHud = %MainHUD
@onready var _scene_fade: ColorRect = %SceneFade

var _click_cursor: AnimatedClickCursor

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scene_fade.hide()
	theme = preload("res://scripts/ui/pop_theme.gd").build()
	_balloon_container.reparent(_main_hud.get_node("%Stage"))
	_balloon_container.custom_minimum_size = Vector2(240, 240)
	_game_session.initialize(content_catalog, balloon_scene, _balloon_container)
	_add_balloon_visual_effects()
	_connect_audio()
	var audio: Variant = get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.apply_settings(_game_session._state.master_volume, _game_session._state.music_volume, _game_session._state.sfx_volume)
		audio.play_gameplay_music()
	_main_hud.bind(_game_session)
	_configure_click_cursor()
	_main_hud.main_menu_requested.connect(_return_to_main_menu)
	_main_hud.quit_requested.connect(get_tree().quit)
	_game_session.refresh_presentation()
	var flow := get_node_or_null("/root/GameFlow") as PopGameFlow
	if flow != null and flow.consume_launch_mode() == PopGameFlow.LaunchMode.ENDLESS:
		_game_session.request_continue_endless()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not _main_hud.is_victory_visible():
		_main_hud.toggle_pause()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_game_session.cancel_hold_click()
		if is_instance_valid(_click_cursor): _click_cursor.reset()

func _add_balloon_visual_effects() -> void:
	var effects := BalloonVisualEffects.new()
	effects.name = "BalloonVisualEffects"
	effects.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Balloons are replaced after each pop. Keep attack companions above every new balloon.
	effects.z_index = 1
	_balloon_container.add_child(effects)
	effects.setup(_game_session)
	_main_hud.pause_visibility_changed.connect(func(is_paused: bool) -> void:
		effects.visible = not is_paused
		if is_paused:
			effects._reset_animations()
	)

func _configure_click_cursor() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ClickCursorLayer"
	layer.layer = 100
	add_child(layer)
	_click_cursor = ClickCursor.new()
	layer.add_child(_click_cursor)
	_click_cursor.setup(_game_session, _main_hud, _scene_fade)

func _return_to_main_menu() -> void:
	_click_cursor.reset()
	_game_session.save_progress()
	get_tree().paused = false
	_scene_fade.show()
	var tween := create_tween()
	tween.tween_property(_scene_fade, "color:a", 1.0, 0.18)
	await tween.finished
	var audio: Variant = get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_menu_music()
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

func _connect_audio() -> void:
	var audio: Variant = get_node_or_null("/root/AudioManager")
	if audio == null:
		return
	var controller := _game_session._balloon_controller
	_game_session.manual_attack_performed.connect(audio.play_manual_hit)
	controller.balloon_damaged.connect(func(_health: float, _maximum: float, attack: AttackResult) -> void:
		if attack.was_critical: audio.play_critical()
	)
	controller.balloon_popped.connect(func(_data: BalloonData) -> void: audio.play_pop())
	controller.special_balloon_popped.connect(func(_data: BalloonData) -> void: audio.play_pop(true))
	_game_session.diamonds_changed.connect(func(_value: int) -> void: audio.play_diamond())
	_game_session.purchase_completed.connect(func(_kind: StringName, _id: StringName, _level: int, milestone: bool) -> void: audio.play_purchase(milestone))
	_game_session.content_revealed.connect(func(_id: StringName) -> void: audio.play_reveal())
	_game_session.balloon_tier_unlocked.connect(func(_id: StringName) -> void: audio.play_unlock())
	_game_session.special_started_audio.connect(audio.play_special_spawn)
	_game_session.buff_started_audio.connect(audio.play_buff)
	_game_session.hold_click_option_changed.connect(audio.play_toggle)
	_game_session.boss_started_audio.connect(audio.start_boss_music)
	_game_session.boss_phase_changed.connect(func(_phase: int, _health: float, _maximum: float) -> void: audio.play_boss_phase())
	_game_session.victory_requested.connect(audio.play_boss_victory)
	_game_session.audio_settings_changed.connect(audio.apply_settings)
