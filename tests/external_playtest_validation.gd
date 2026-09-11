extends SceneTree

const SAVE := "res://tests/external_playtest_save.json"
const CAPTURES := "res://tests/external_playtest_captures"
const Numbers = preload("res://scripts/ui/number_format.gd")

var failures: Array[String] = []
var game: Game

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	create_timer(45.0).timeout.connect(func() -> void: push_error("External playtest validation timed out"); quit(2))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURES))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE.get_basename() + "_settings.json"))
	var catalog := load("res://data/content_catalog.tres") as ContentCatalogData
	var save := root.get_node("SaveManager") as PopSaveManager
	save.set_save_path_for_testing(SAVE)
	_validate_number_format()
	_validate_v9_migration(catalog)
	var state := _completed_state(catalog)
	state.master_volume = 0.0
	check(save.save_game_state(state), "Could not seed isolated playtest save")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game = load("res://scenes/main/game.tscn").instantiate() as Game
	root.add_child(game)
	current_scene = game
	await create_timer(0.5).timeout
	game._game_session._auto_damage_timer.stop()
	var session := game._game_session
	var hud := game._main_hud
	check(not hud.is_victory_visible(), "Completed save must not reopen Victory/Credits")
	check(not hud._objective_label.visible, "Completed campaign must not show a stale next-balloon objective")
	check(hud._diamonds_label.visible and hud._diamonds_label.text == "10", "Diamond counter must remain visible and stable")
	check(not hud._click_damage_label.text.contains("Lv."), "Main HUD Click stat must omit its level")
	check(hud._tier_label.text.contains("COINS"), "Current Balloon header must show final Coin reward")
	check(hud._hold_click_toggle.get_parent() != hud._status_row, "Hold to Click must live in Settings")
	check(hud.get_theme_stylebox("tab_hovered", "TabContainer") != null, "Tab hover style must preserve a bordered stylebox")
	await _validate_buy_modes(session, hud)
	await _validate_hold_and_hp(session, hud, catalog)
	await _validate_endless_navigation(session, catalog)
	await _validate_boss_completion_return(session, hud, catalog)
	await _validate_diamonds_and_stats(session, hud, catalog)
	await _capture_tier(session, &"golden_balloon", "dark_balloon")
	await _capture_tier(session, &"rainbow_balloon", "rainbow_balloon")
	check(session._state.is_balloon_unlocked(&"golden_balloon") and session._state.is_balloon_unlocked(&"rainbow_balloon"), "Tier history must remain unlocked")
	session.save_progress()
	game.queue_free()
	await process_frame
	game = null
	current_scene = null
	await create_timer(0.25).timeout
	game = load("res://scenes/main/game.tscn").instantiate() as Game
	root.add_child(game)
	current_scene = game
	await create_timer(0.4).timeout
	check(not game._main_hud.is_victory_visible(), "Reloaded Endless save must not replay Credits")
	check(game._game_session._state.is_balloon_unlocked(&"golden_balloon"), "Reloaded Endless save lost older tiers")
	game.queue_free()
	await process_frame
	game = null
	var audio := root.get_node("AudioManager") as PopAudioManager
	audio._stop_music(0.0)
	await create_timer(0.35).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE.get_basename() + "_settings.json"))
	print("EXTERNAL_PLAYTEST_RESULTS: ", failures)
	quit(0 if failures.is_empty() else 1)

func _completed_state(catalog: ContentCatalogData) -> GameState:
	var state := GameState.new()
	state.coins = 10000000
	state.diamonds = 10
	state.diamonds_earned = 10
	state.click_damage_level = 30
	for balloon: BalloonData in catalog.balloons:
		if balloon.category == BalloonData.Category.NORMAL: state.unlock_balloon(balloon.id)
	state.current_normal_balloon_id = &"rainbow_balloon"
	state.campaign_completed = true
	state.campaign_completion_presented = true
	state.endless_unlocked = true
	state.balloon_king_defeated_count = 1
	return state

func _validate_number_format() -> void:
	check(Numbers.compact(421.237491) == "421.24", "Small decimals must use two places")
	check(Numbers.compact(2400) == "2.40K" and Numbers.compact(2400000) == "2.40M", "Large number suffix formatting failed")
	check(Numbers.compact(29.0) == "29" and Numbers.percent(0.033) == "3.30%" and Numbers.multiplier(2.5) == "×2.50", "Integer, percent, or multiplier formatting failed")

func _validate_v9_migration(catalog: ContentCatalogData) -> void:
	var legacy := _completed_state(catalog).to_save_data()
	legacy["save_version"] = 9
	(legacy["upgrades"] as Dictionary).erase("diamond_event_frequency_level")
	(legacy["progression"] as Dictionary).erase("campaign_completion_presented")
	(legacy["statistics"] as Dictionary).erase("balloon_king_defeated_count")
	(legacy["settings"] as Dictionary).erase("hold_click_enabled")
	var migrated := GameState.from_save_data(legacy, catalog)
	check(migrated != null and migrated.campaign_completion_presented and migrated.balloon_king_defeated_count == 1, "v9 campaign migration failed")
	check(migrated.diamond_event_frequency_level == 0 and not migrated.hold_click_enabled, "v9 defaults are unsafe")

func _validate_buy_modes(session: GameSession, hud: MainHud) -> void:
	session._state.click_damage_level = 14
	session._state.coins = 1450
	session.set_buy_mode(GameSession.BuyMode.TEN)
	var ten_quote := session.get_purchase_quote(&"click")
	check(ten_quote["count"] == 5 and ten_quote["total"] == 1105, "×10 quote must sum rising costs and show only the affordable levels")
	hud._render_cards()
	check(hud._click_upgrade_button.text.contains("×5") and hud._click_upgrade_button.text.contains("1.11K"), "×10 button must display its actual quantity and total cost")
	session.set_buy_mode(GameSession.BuyMode.MAX)
	var max_quote := session.get_purchase_quote(&"click")
	check(max_quote["count"] == 5 and max_quote["total"] == 1105, "MAX quote must show the affordable quantity and total cost")
	hud._render_cards()
	check(hud._click_upgrade_button.text.contains("×5") and hud._click_upgrade_button.text.contains("1.11K"), "MAX button must display its affordable quantity and total cost")
	session._state.click_damage_level = 1
	session._state.coins = 100
	session.set_buy_mode(GameSession.BuyMode.TEN)
	session.request_click_upgrade()
	check(session._state.click_damage_level == 8 and session._state.coins == 10, "×10 must buy the largest affordable amount using rising costs")
	session._state.click_damage_level = 30
	session._state.coins = 10000000
	session._state.set_equipment_level(&"needle", 39)
	session.set_buy_mode(GameSession.BuyMode.MAX)
	session.request_equipment_upgrade(&"needle")
	check(session._state.get_equipment_level(&"needle") == 40, "MAX must stop at equipment level cap")
	session._state.diamonds = 1000
	session._state.set_global_upgrade_level(&"auto_dps_core", 4)
	session.request_global_upgrade(&"auto_dps_core")
	check(session._state.get_global_upgrade_level(&"auto_dps_core") == 10, "MAX must stop at Global Upgrade cap")
	await process_frame
	check(hud._buy_max_button.button_pressed, "Selected buy mode is not visually evident")
	var click_card = hud._cards[hud._click_upgrade_button]
	check(not click_card.tooltip_text.is_empty() and hud._click_upgrade_button.tooltip_text == click_card.tooltip_text, "Whole upgrade card, including its Buy button, needs the same tooltip")

func _validate_hold_and_hp(session: GameSession, hud: MainHud, catalog: ContentCatalogData) -> void:
	session.set_hold_click_enabled(true)
	var balloon := session._balloon_controller._current_balloon
	var point := balloon.get_global_transform_with_canvas() * (balloon.size * Vector2(0.5, 0.47))
	session._on_balloon_hold_started()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	session._input(motion)
	check(not session._hold_click_timer.is_stopped(), "Hold did not start")
	motion = InputEventMouseMotion.new()
	motion.position = Vector2(20, 20)
	session._input(motion)
	var clicks_before_outside_tick := session._state.total_clicks
	session._on_hold_click_tick()
	check(not session._hold_click_timer.is_stopped(), "Hold must remain armed when the cursor leaves the Balloon")
	check(session._state.total_clicks == clicks_before_outside_tick, "Hold outside the Balloon must not deal manual damage")
	motion.position = point
	session._input(motion)
	session._balloon_controller.damage_current_balloon(AttackResult.new(session._balloon_controller.get_current_health() + 1.0))
	await create_timer(0.2).timeout
	check(not session._hold_click_timer.is_stopped(), "Hold must remain armed through Balloon pop and respawn")
	hud.toggle_pause()
	check(session._hold_click_timer.is_stopped(), "Pause must cancel Hold immediately")
	hud._resume_game()
	var probe := load("res://scenes/balloons/balloon.tscn").instantiate() as Balloon
	root.add_child(probe)
	probe.set_deferred("size", Vector2(240, 240))
	await process_frame
	probe.configure(catalog.find_balloon(&"red_balloon"), 10.0, 10.0)
	probe.take_damage(AttackResult.new(3.0))
	check(probe._health_bar.value == 7.0 and not probe._damage_lag.visible, "HP bar must immediately match non-fatal damage without a delayed overlay")
	probe.take_damage(AttackResult.new(7.0))
	check(probe.get_current_health() == 0.0 and probe._health_bar.value == 0.0 and probe._damage_lag.value == 0.0, "Fatal hit did not synchronize HP bars to zero")
	check(probe._health_bar.visible, "HP bar vanished before zero could be presented")
	probe.free()

func _validate_endless_navigation(session: GameSession, catalog: ContentCatalogData) -> void:
	session.request_continue_endless()
	session.request_previous_balloon()
	check(session._state.current_normal_balloon_id == &"golden_balloon" and catalog.find_balloon(&"golden_balloon").display_name == "Dark Balloon", "Previous from Rainbow must return to Dark")
	session.request_next_unlocked_balloon()
	check(session._state.current_normal_balloon_id == &"rainbow_balloon", "Next unlocked must return to Rainbow")

func _validate_boss_completion_return(session: GameSession, hud: MainHud, catalog: ContentCatalogData) -> void:
	var king := catalog.find_balloon(&"balloon_king")
	check(king != null, "Balloon King content missing")
	if king == null:
		return
	session._state.campaign_completed = false
	session._state.endless_unlocked = false
	session._balloon_controller.start_boss(king)
	session._on_boss_popped(king)
	check(not session._balloon_controller.is_boss_active(), "Boss state must end immediately after victory")
	check(not hud._objective_label.visible, "Boss objective must disappear after victory")
	hud._continue_into_endless()
	check(session._state.current_normal_balloon_id == &"rainbow_balloon", "Endless must return to a normal Balloon without restart")
	session.request_previous_balloon()
	check(session._state.current_normal_balloon_id == &"golden_balloon", "Previous Balloon navigation must work immediately after victory")

func _validate_diamonds_and_stats(session: GameSession, hud: MainHud, catalog: ContentCatalogData) -> void:
	var event_state := GameState.new()
	event_state.unlock_balloon(&"blue_balloon")
	event_state.unlock_balloon(&"green_balloon")
	for _pop in 20:
		event_state.record_balloon_pop(&"green_balloon")
	var reveal := RevealService.new(event_state, catalog)
	reveal.initialize()
	check(reveal.is_revealed(&"crystal_balloon"), "Crystal must unlock after 20 Green pops, before Purple")
	check(reveal.is_revealed(&"electric_balloon") and reveal.is_revealed(&"frenzy_balloon"), "Electric and Frenzy must join the rotation when Blue is unlocked")
	check(catalog.find_balloon(&"crystal_balloon").base_health <= catalog.find_balloon(&"green_balloon").base_health, "Early Crystal must be poppable with Green-stage power")
	var scheduler := SpecialBalloonScheduler.new()
	root.add_child(scheduler)
	scheduler.setup(catalog, reveal, event_state)
	scheduler._diamond_event_timer.stop()
	scheduler._active = catalog.find_balloon(&"golden_special_balloon")
	scheduler._try_start_diamond_event()
	check(scheduler._diamond_event_pending, "Crystal event must remain pending behind another special")
	scheduler.complete_active_special()
	await process_frame
	check(scheduler._active != null and scheduler._active.id == &"crystal_balloon", "Pending Crystal event did not start when the special slot became free")
	scheduler.queue_free()
	var before := session._state.diamonds
	session._on_balloon_popped(catalog.find_balloon(&"red_balloon"))
	check(session._state.diamonds == before, "Normal Balloon pop granted a Diamond")
	session._state.crystal_balloons_popped = 1
	session._state.diamond_reward_level = 0
	session._on_special_balloon_popped(catalog.find_balloon(&"crystal_balloon"))
	check(session._state.diamonds == before + 1, "Crystal Diamond event did not grant its Diamond")
	var old_interval := session.get_diamond_event_interval_seconds()
	session.set_buy_mode(GameSession.BuyMode.ONE)
	session.request_diamond_event_frequency_upgrade()
	check(session._state.diamond_event_frequency_level == 1 and session.get_diamond_event_interval_seconds() < old_interval, "Diamond Event Frequency purchase did not improve only its timer")
	check(is_equal_approx(session._special_scheduler._diamond_event_timer.wait_time, session.get_diamond_event_interval_seconds()), "Diamond event timer did not refresh")
	hud._toggle_statistics()
	check(hud._statistics_panel.visible and hud._statistics_text.text.contains("Dark Balloon popped") and hud._statistics_text.text.contains("Total Balloons popped"), "Statistics panel is incomplete")
	hud._toggle_statistics()

func _capture_tier(session: GameSession, id: StringName, label: String) -> void:
	session._balloon_controller.set_current_normal_balloon(id)
	session.current_balloon_changed.emit(session._get_current_balloon_text())
	await create_timer(0.15).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(CAPTURES + "/" + label + ".png")
