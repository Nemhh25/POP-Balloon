extends SceneTree

const OUTPUT := "res://tests/interaction_captures"
const SAVE := OUTPUT + "/test_progress.json"
var failures: Array[String] = []
var game: Game

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(50.0).timeout.connect(func() -> void:
		push_error("Interaction validation timed out")
		quit(2)
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var save := root.get_node("SaveManager") as PopSaveManager
	save.set_save_path_for_testing(SAVE)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var state := GameState.new()
	state.unlock_balloon(&"blue_balloon")
	state.current_normal_balloon_id = &"blue_balloon"
	state.set_equipment_level(&"needle", 1)
	state.set_equipment_level(&"dart", 1)
	state.master_volume = 0.0
	save.save_game_state(state)
	game = load("res://scenes/main/game.tscn").instantiate() as Game
	root.add_child(game)
	current_scene = game
	await create_timer(0.5).timeout
	game._game_session._auto_damage_timer.stop()
	await create_timer(0.4).timeout
	await capture("small_idle")
	game._game_session._on_auto_damage_tick()
	await create_timer(0.09).timeout
	await capture("small_attack")
	await _validate_interactions()
	game.queue_free()
	await process_frame
	game = null
	current_scene = null
	# Let the audio backend release playback before the test terminates the engine.
	var audio := root.get_node("AudioManager") as PopAudioManager
	audio._stop_music(0.0)
	await create_timer(0.4).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OUTPUT + "/test_progress_settings.json"))
	print("INTERACTION_VALIDATION_RESULTS: ", failures)
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func move_pointer(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	root.push_input(event)

func click_pointer(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = pressed
	root.push_input(event)

func _validate_interactions() -> void:
	var session := game._game_session
	var controller := session._balloon_controller
	var effects := game._balloon_container.get_node("BalloonVisualEffects") as BalloonVisualEffects
	var cursor := game._click_cursor
	var balloon := controller._current_balloon
	var point := balloon.get_global_transform_with_canvas() * (balloon.size * Vector2(0.5, 0.47))
	move_pointer(point)
	await process_frame
	await capture("cursor_hover")
	check(cursor._owns_mouse and cursor._sprite.visible, "Hover must display a single software cursor")
	var hp := balloon.get_current_health()
	click_pointer(point, true)
	var maximum_press := 0.0
	for frame in 6:
		await process_frame
		maximum_press = maxf(maximum_press, cursor._sprite.position.distance_to(-cursor.HOTSPOT))
		if frame == 1: await capture("cursor_press")
	check(balloon.get_current_health() < hp, "Valid manual click must still damage balloon")
	check(maximum_press > 2.0, "Cursor must physically press, not stay static")
	click_pointer(point, false)
	await create_timer(0.14).timeout
	check(cursor._sprite.position.is_equal_approx(-cursor.HOTSPOT), "Manual cursor must return to idle")
	await capture("cursor_return")
	for _i in 15:
		click_pointer(point, true)
		click_pointer(point, false)
		await create_timer(0.02).timeout
	await create_timer(0.14).timeout
	check(cursor._sprite.position.is_equal_approx(-cursor.HOTSPOT), "Rapid clicks cannot trap cursor pressed")
	session.set_hold_click_enabled(true)
	click_pointer(point, true)
	# `push_input()` does not move the operating-system cursor used by
	# Viewport.get_mouse_position(), so keep the synthetic pointer explicit.
	session._hold_pointer_position = point
	check(session._hold_mouse_down and not session._hold_click_timer.is_stopped(), "Hold ON press did not arm the repeat timer")
	var clicks := session._state.total_clicks
	await create_timer(0.45).timeout
	check(session._state.total_clicks >= clicks + 3, "Hold ON must keep generating real manual clicks")
	await capture("cursor_hold")
	click_pointer(point, false)
	clicks = session._state.total_clicks
	await create_timer(0.2).timeout
	check(session._state.total_clicks == clicks, "Release must stop Hold input")
	check(cursor._sprite.position.is_equal_approx(-cursor.HOTSPOT), "Hold release must reset cursor")
	session.set_hold_click_enabled(false)
	click_pointer(point, true)
	clicks = session._state.total_clicks
	await create_timer(0.3).timeout
	check(session._state.total_clicks == clicks, "Hold OFF cannot repeat clicks")
	click_pointer(point, false)
	move_pointer(Vector2(40, 120))
	click_pointer(Vector2(40, 120), true)
	click_pointer(Vector2(40, 120), false)
	await create_timer(0.04).timeout
	check(not cursor._sprite.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Outside click must restore native cursor")
	var settings_point := game._main_hud._settings_button.get_global_rect().get_center()
	move_pointer(settings_point)
	click_pointer(settings_point, true)
	click_pointer(settings_point, false)
	await process_frame
	check(game._main_hud._audio_settings_panel.visible and not cursor._sprite.visible, "UI Settings click cannot play strong cursor pulse")
	game._main_hud._audio_settings_panel.hide()
	await _validate_equipment_and_tiers()
	move_pointer(point)
	await process_frame
	game._main_hud.toggle_pause()
	await create_timer(0.3).timeout
	check(not cursor._sprite.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Pause restores native cursor")
	check(not effects.visible, "Pause must hide equipment sprites behind the overlay")
	check(effects._active_projectiles.is_empty(), "Pause must release projectiles")
	for effect: Dictionary in effects._effects:
		check(effect.node.position.is_equal_approx(effect.rest_position), "Pause returns equipment to rest")
	await capture("pause")
	game._main_hud._resume_game()
	await create_timer(0.2).timeout
	check(effects.visible, "Resume must restore equipment sprites")
	# Use a nonlethal real tick so the screenshot validates the live boss, not victory.
	for equipment: EquipmentData in session._catalog.equipment:
		session._state.set_equipment_level(equipment.id, 10)
	session.refresh_presentation()
	session.request_unlock_next_balloon()
	await create_timer(0.1).timeout
	check(controller.is_boss_active(), "Boss fixture should enter the real challenge")
	session._on_auto_damage_tick()
	await create_timer(0.075).timeout
	check(controller.is_boss_active() and controller.get_current_health() > 0.0, "Boss must stay alive during attack validation")
	await capture("boss_attack")
	controller.damage_current_balloon(AttackResult.new(controller.get_current_health() + 1.0))
	await process_frame
	check(game._main_hud.is_victory_visible() and not cursor._sprite.is_visible_in_tree(), "Boss victory must hide interaction visuals")
	await capture("victory")
	game._main_hud._continue_into_endless()
	await create_timer(0.4).timeout
	move_pointer(point)
	await process_frame
	var returning := game
	returning._return_to_main_menu()
	await create_timer(0.45).timeout
	check(current_scene is MainMenu and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Menu transition must release software cursor")
	game = null
	# The next run uses the same isolated save through the real Continue entry.
	change_scene_to_file("res://scenes/main/game.tscn")
	await create_timer(0.3).timeout
	game = current_scene as Game
	check(game != null, "Gameplay reload must succeed")

func _validate_equipment_and_tiers() -> void:
	var session := game._game_session
	var controller := session._balloon_controller
	var effects := game._balloon_container.get_node("BalloonVisualEffects") as BalloonVisualEffects
	var tiers := [&"red_balloon", &"blue_balloon", &"green_balloon", &"purple_balloon", &"golden_balloon", &"rainbow_balloon"]
	var counts := [1, 2, 2, 4, 6, 7]
	for tier_index in tiers.size():
		for i in session._catalog.equipment.size():
			session._state.set_equipment_level(session._catalog.equipment[i].id, (1 if tier_index < 2 else 10) if i < counts[tier_index] else 0)
		session._state.unlock_balloon(tiers[tier_index])
		controller.set_current_normal_balloon(tiers[tier_index])
		session.refresh_presentation()
		await create_timer(0.2).timeout
		check(effects._effects.size() == counts[tier_index], "Only owned equipment should appear")
		var radius := effects._get_balloon_radius()
		var center := effects._get_balloon_center()
		for effect: Dictionary in effects._effects:
			var icon: TextureRect = effect.node
			check(icon.size.x <= 50.01 and icon.size.y <= 50.01, "Atlas cannot expand sprites beyond the bounded 50-pixel presentation size")
			check((icon.position + icon.size * 0.5).distance_to(center) - icon.size.length() * 0.5 > radius + 5.0, "Equipment idle must fully clear balloon edge")
		await capture(String(tiers[tier_index]) + "_idle")
		var hp := controller.get_current_health()
		var expected := session.get_auto_dps() * session._balance.get_auto_damage_tick_interval()
		session._on_auto_damage_tick()
		check(is_equal_approx(controller.get_current_health(), maxf(0.0, hp - expected)), "Visual attacks must preserve exact Auto DPS damage")
		await create_timer(0.085).timeout
		for effect: Dictionary in effects._effects:
			var icon: TextureRect = effect.node
			check((icon.position + icon.size * 0.5).distance_to(center) > radius * 0.85, "Attacks cannot cross balloon center")
		await capture(String(tiers[tier_index]) + "_attack")
		session._auto_damage_timer.start()
		await create_timer(0.65).timeout
		session._auto_damage_timer.stop()
		await create_timer(0.4).timeout
	for equipment: EquipmentData in session._catalog.equipment:
		session._state.set_equipment_level(equipment.id, equipment.max_level)
	session.refresh_presentation()
	var nodes_before := effects.get_child_count()
	for _i in 1000:
		controller.damage_current_balloon(AttackResult.new(0.001))
	var attackers := 0
	for effect: Dictionary in effects._effects:
		if effects._is_effect_attacking(effect): attackers += 1
	check(attackers <= 2 and effects.get_child_count() == nodes_before, "1000 ticks must not spawn nodes or animate all equipment")
	await create_timer(0.08).timeout
	await capture("high_dps")
	controller.damage_current_balloon(AttackResult.new(controller.get_current_health() + 1.0))
	await create_timer(0.2).timeout
	check(effects._active_projectiles.is_empty(), "Pop/respawn must reclaim all projectiles")
	check(controller._current_balloon.get_current_health() > 0.0, "Next balloon must survive visual cleanup")
	var resized_to := [Vector2i(960, 540), Vector2i(1920, 1080), Vector2i(1280, 720)]
	for resolution in resized_to:
		root.size = resolution
		await create_timer(0.12).timeout
		await capture("layout_%dx%d" % [resolution.x, resolution.y])

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "/" + label + ".png")
