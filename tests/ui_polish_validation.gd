extends SceneTree

const PATH := "res://tests/ui_polish_save.json"
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/ui_captures/polish_%s.png" % name)

func pointer(control: Control, at: Vector2, click: bool = true) -> void:
	var point := control.global_position + at
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	if click:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = true
		root.push_input(event)
		event = event.duplicate()
		event.pressed = false
		root.push_input(event)

func run() -> void:
	var save := root.get_node("SaveManager") as PopSaveManager
	save.set_save_path_for_testing(PATH)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var state := GameState.new()
	state.coins = 500000
	state.click_damage_level = 4
	state.unlock_balloon(&"blue_balloon")
	state.unlock_balloon(&"green_balloon")
	state.current_normal_balloon_id = &"blue_balloon"
	save.save_game_state(state)
	var game := load("res://scenes/main/game.tscn").instantiate() as Game
	root.add_child(game)
	await create_timer(0.3).timeout
	var hud := game._main_hud
	var session := game._game_session
	var controller := session._balloon_controller
	var balloon := controller._current_balloon
	check(not hud._needle_button.visible, "Needle must start hidden")
	var hp := balloon.get_current_health()
	pointer(balloon, balloon.size * Vector2(0.5, 0.46))
	check(balloon.get_current_health() < hp, "Actual pointer click failed")
	check(balloon._hovered, "Hover missing")
	await create_timer(0.08).timeout
	await capture("normal")
	var click := hud._click_upgrade_button
	pointer(click, click.size * 0.5)
	await create_timer(0.06).timeout
	check(session.get_click_damage_level() == 5, "Actual shop click failed")
	check(hud._cards[hud._needle_button].badge.visible, "NEW card missing")
	check(hud._tabs.get_tab_title(1).contains("NEW"), "NEW tab missing")
	await capture("new")
	hud._tabs.current_tab = 1
	await create_timer(0.18).timeout
	check(not hud._tabs.get_tab_title(1).contains("NEW"), "Tab badge did not clear")
	for i in 10:
		session.request_needle_upgrade()
		await process_frame
	await create_timer(0.04).timeout
	check(hud._cards[hud._needle_button].badge.text.contains("MILESTONE"), "Milestone missing")
	await capture("milestone")
	pointer(hud._needle_button, hud._needle_button.size * 0.5, false)
	check(not hud._cards[hud._needle_button].badge.visible, "Seen badge did not clear")
	session._economy.add_diamonds(1)
	controller.damage_current_balloon(AttackResult.new(15, true, 1.0, true))
	hud._on_combo_changed(session._catalog.balance.combo_max_stacks, 2.0)
	await create_timer(0.06).timeout
	await capture("critical_diamond")
	var has_manual_damage := false
	for lane: String in hud._feedback_lanes:
		if lane.begins_with("manual_"):
			has_manual_damage = true
	check(has_manual_damage and hud._feedback_lanes.has("diamonds"), "Manual damage and Diamond must coexist")
	session._buffs.activate(&"electric", 2.0, 0.3)
	await create_timer(0.04).timeout
	check(hud._buff_label.visible, "Buff entrance missing")
	await create_timer(0.5).timeout
	check(not hud._buff_label.visible, "Buff exit missing")
	hud._on_combo_changed(0, 1.0)
	hud._toggle_audio_settings()
	pointer(hud._hold_click_toggle, hud._hold_click_toggle.size * 0.5)
	check(session.is_hold_click_enabled(), "Hold toggle failed")
	hud._toggle_audio_settings()
	session._state.balloon_pops_by_id[&"green_balloon"] = 10000
	session.refresh_presentation()
	await create_timer(0.05).timeout
	await capture("progression")
	session.request_unlock_next_balloon()
	await process_frame
	check(session._state.is_balloon_unlocked(&"purple_balloon"), "Unlock failed")
	hud._tabs.current_tab = 0
	for i in 80:
		controller.damage_current_balloon(AttackResult.new(1e12, i % 2 == 0, 1.0, true))
		await create_timer(0.16).timeout
		check(hud._effects.get_child_count() <= 10, "Feedback nodes accumulating")
		check(game._balloon_container.get_child_count() <= 2, "Balloon nodes accumulating")
	await capture("rapid")
	session._auto_damage_timer.stop()
	await create_timer(1.0).timeout
	check(hud._effects.get_child_count() <= 1, "Feedback did not expire")
	check(get_processed_tweens().size() < 60, "Tweens accumulating")
	session._state.coins = 0
	session._state.critical_damage_level = session._catalog.balance.critical_damage_max_level
	session.refresh_presentation()
	await create_timer(0.05).timeout
	check(hud._click_upgrade_button.disabled, "Unaffordable button not disabled")
	check(hud._critical_damage_button.text == "MAX", "MAX completion missing")
	await capture("max_unaffordable")
	save.save_game_state(session._state)
	game.free()
	await process_frame
	game = load("res://scenes/main/game.tscn").instantiate() as Game
	root.add_child(game)
	await create_timer(0.2).timeout
	check(game._game_session.is_hold_click_enabled(), "Hold setting did not persist")
	check(game._game_session._state.is_balloon_unlocked(&"purple_balloon"), "Progress save/load failed")
	game.free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH.get_basename() + "_settings.json"))
	(root.get_node("AudioManager") as PopAudioManager)._stop_music(0.0)
	await create_timer(0.35).timeout
	print("UI_POLISH_RESULTS: ", failures)
	quit(0 if failures.is_empty() else 1)
