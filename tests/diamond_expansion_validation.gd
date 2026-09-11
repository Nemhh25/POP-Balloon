extends SceneTree

var failures: Array[String] = []
const SAVE := "res://tests/diamond_expansion_save.json"

func _init() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	create_timer(40.0).timeout.connect(func(): quit(2))
	var catalog := load("res://data/content_catalog.tres") as ContentCatalogData
	var balance := BalanceService.new(catalog.balance)
	var expected := {24: 24.0, 25: 27.5, 26: 28.6, 49: 53.9, 50: 60.0, 75: 97.5, 100: 140.0, 250: 500.0}
	for level: int in expected:
		check(is_equal_approx(balance.get_base_click_damage(level), float(level)), "Linear base at %d" % level)
		check(is_equal_approx(balance.get_click_damage(level), expected[level]), "Additive milestone at %d" % level)
		check(balance.get_next_click_milestone(level) > level, "Unlimited next milestone")
	check(balance.get_critical_damage_multiplier(5) == 2.5, "Base critical cap unchanged")
	var state := GameState.new()
	state.coins = 1000000
	state.diamonds = 200
	state.diamonds_earned = 200
	state.click_damage_level = 24
	# Existing save fields, including legacy Click Core, must survive loading.
	state.set_global_upgrade_level(&"click_core", 2)
	var old_data := state.to_save_data()
	var restored := GameState.from_save_data(old_data, catalog)
	check(restored != null and restored.coins == state.coins and restored.diamonds == state.diamonds, "Legacy currency preserved")
	check(restored.get_global_upgrade_level(&"click_core") == 2 and restored.get_global_upgrade_level(&"buff_power") == 0, "Legacy levels preserved, new defaults zero")
	var save := root.get_node("SaveManager") as PopSaveManager
	save.set_save_path_for_testing(SAVE)
	check(save.save_game_state(state), "Seed isolated save")
	var game := load("res://scenes/main/game.tscn").instantiate() as Game
	root.add_child(game)
	current_scene = game
	await process_frame
	var session := game._game_session
	var hud := game._main_hud
	session._auto_damage_timer.stop()
	session._special_scheduler._diamond_event_timer.stop()
	check(not session.can_buy_global_upgrade(&"click_core"), "Legacy Click Core cannot be bought")
	check(not session.is_global_upgrade_revealed(&"buff_power"), "Late global hidden early")
	var before := session.get_diamonds()
	session.request_global_upgrade(&"buff_power")
	check(session.get_diamonds() == before, "Hidden upgrade cannot be purchased through session")
	session.request_click_upgrade()
	await process_frame
	check(is_equal_approx(session.get_click_damage(), 27.5), "Level 25 real upgrade")
	check(hud._cards[hud._click_upgrade_button]._click_milestone_active, "Milestone feedback active")
	check(hud._cards[hud._click_upgrade_button].progress.value == 25, "Milestone briefly full")
	await create_timer(1.0).timeout
	check(hud._cards[hud._click_upgrade_button].progress.value == 0, "Milestone resets to next interval")
	for balloon: BalloonData in catalog.balloons:
		if balloon.category == BalloonData.Category.NORMAL: session._state.unlock_balloon(balloon.id)
	session._state.buff_frequency_unlocked = true
	session._state.crystal_balloons_popped = 1
	session._state.critical_chance_level = 3
	session.refresh_presentation()
	await process_frame
	check(hud._global_buttons.size() == 7, "Seven distinct globals plus existing Diamond frequency")
	for data: GlobalUpgradeData in catalog.global_upgrades:
		if data.legacy_only: continue
		session._state.set_global_upgrade_level(data.id, 0)
		session._state.diamonds = 0
		check(not session.can_buy_global_upgrade(data.id), "Zero Diamonds prevents purchase")
		session._state.diamonds = 1
		session.set_buy_mode(GameSession.BuyMode.ONE)
		session.request_global_upgrade(data.id)
		check(session.get_global_upgrade_level(data.id) == 1 and session.get_diamonds() == 0, "Level one spends one Diamond")
		session._state.diamonds = 5
		session.set_buy_mode(GameSession.BuyMode.MAX)
		var quote := session.get_purchase_quote(&"global", data.id)
		check(quote.count == 2 and quote.total == 5, "MAX uses rising costs")
		session.request_global_upgrade(data.id)
		check(session.get_global_upgrade_level(data.id) == 3 and session.get_diamonds() == 0, "MAX matches preview")
		session._state.diamonds = 1000
		session.set_buy_mode(GameSession.BuyMode.TEN)
		session.request_global_upgrade(data.id)
		check(session.get_global_upgrade_level(data.id) == data.max_level, "x10 respects cap")
		before = session.get_diamonds()
		session.request_global_upgrade(data.id)
		check(session.get_diamonds() == before, "No spend above cap")
		session.refresh_presentation()
		await process_frame
		var button: Button = hud._global_buttons[data.id]
		check(button.text == "MAX" and button.disabled, "Card MAX disabled")
		check(hud._cards[button].tooltip_text.contains(data.description), "Full card description")
		check(button.tooltip_text.contains("MAX"), "Tooltip includes cap state")
	var base_dps := session._equipment.get_total_auto_dps()
	session._state.set_equipment_level(&"needle", 1)
	base_dps = session._equipment.get_total_auto_dps()
	check(is_equal_approx(session.get_auto_dps(), base_dps * 1.5), "Real Auto DPS multiplier")
	check(session._get_normal_balloon_coin_reward(catalog.find_balloon(&"red_balloon")) == roundi(5 * 1.5), "Real normal Coin multiplier")
	check(session._get_special_balloon_coin_reward(catalog.find_balloon(&"crystal_balloon")) == 22500, "Special Coins included")
	var scheduler := session._special_scheduler
	scheduler.refresh_special_frequency()
	session._state.set_global_upgrade_level(&"special_frequency", 0)
	check(session.get_buff_special_pop_interval(0) == 45, "Buff specials use 45 normal pops at base frequency")
	check(scheduler._diamond_event_timer.wait_time == 18.0, "Special frequency leaves Crystal unchanged")
	scheduler._reveal_service._revealed[&"golden_special_balloon"] = true
	scheduler._reveal_service._revealed[&"electric_balloon"] = true
	scheduler._reveal_service._revealed[&"frenzy_balloon"] = true
	var buff_events: Array[StringName] = []
	scheduler.special_started.connect(func(balloon: BalloonData) -> void:
		if balloon.id in [&"electric_balloon", &"frenzy_balloon"]:
			buff_events.append(balloon.id)
	)
	scheduler.notify_normal_balloon_popped(44)
	check(buff_events.is_empty(), "No buff special before the pop threshold")
	scheduler.notify_normal_balloon_popped(45)
	check(buff_events.size() == 1, "A buff special starts at pop 45 even when Golden is also due")
	scheduler.complete_active_special()
	session._state.set_global_upgrade_level(&"special_frequency", 8)
	check(scheduler.get_buff_event_pop_interval() == 33, "Special frequency reduces the 45-pop threshold")
	scheduler.notify_normal_balloon_popped(66)
	check(buff_events.size() == 2 and buff_events[0] != buff_events[1], "Buff specials alternate without immediate repeats")
	scheduler.complete_active_special()
	session._activate_global_buff(BuffService.ELECTRIC_ID, 2.0, 12.0)
	check(is_equal_approx(session._buffs.get_multiplier(BuffService.ELECTRIC_ID), 2.4), "Buff Power amplifies only bonus")
	var remaining := (float(session._buffs._active[BuffService.ELECTRIC_ID].expires_at) - Time.get_ticks_msec()) / 1000.0
	check(remaining > 16.5 and remaining <= 16.8, "Buff duration 40 percent")
	session._combo_stacks = 25
	check(is_equal_approx(session.get_combo_multiplier(), 1.0 + 24 * 0.07 * 1.24), "Combo effect bonus only")
	check(is_equal_approx(session._globals.get_effect_multiplier(GlobalUpgradeData.Effect.CRITICAL_DAMAGE), 1.24), "Critical Mastery separate multiplier")
	session._state.diamonds = 100
	session.set_buy_mode(GameSession.BuyMode.MAX)
	session.request_diamond_event_frequency_upgrade()
	check(session._state.diamond_event_frequency_level == 5, "Existing Diamond Frequency cap")
	check(is_equal_approx(scheduler._diamond_event_timer.wait_time, 12.6), "Diamond Frequency remains independent")
	session._state.click_damage_level = 250
	session.save_progress()
	var loaded := save.load_game_state(catalog)
	check(loaded.click_damage_level == 250 and loaded.get_global_upgrade_level(&"buff_power") == 10, "Disk save/load levels")
	check(loaded.diamond_event_frequency_level == 5 and loaded.get_global_upgrade_level(&"click_core") == 2, "Disk preserves event and legacy")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1280, 720)
		session._state.click_damage_level = 47
		for data: GlobalUpgradeData in catalog.global_upgrades:
			if not data.legacy_only: session._state.set_global_upgrade_level(data.id, 2)
		session.refresh_presentation()
		hud._tabs.current_tab = 2
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/diamond_globals.png")
		hud._tabs.current_tab = 0
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/click_milestones.png")
	game.queue_free()
	await process_frame
	root.get_node("AudioManager")._stop_music(0.0)
	await create_timer(0.35).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE.get_basename() + "_settings.json"))
	print("DIAMOND_EXPANSION_RESULTS: ", failures)
	quit(0 if failures.is_empty() else 1)
