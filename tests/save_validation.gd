extends SceneTree

const TEST_SAVE_PATH := "res://tests/save_validation.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog := load("res://data/content_catalog.tres") as ContentCatalogData
	var state := GameState.new()
	var balance := BalanceService.new(catalog.balance)
	var economy := EconomyService.new(state)
	var upgrades := UpgradeService.new(state, balance, economy)
	var equipment := EquipmentService.new(state, catalog, balance, economy)
	var progression := ProgressionService.new(state, catalog, economy)
	if balance.get_click_upgrade_cost(1) != 5 or balance.get_click_upgrade_cost(5) != 15 or balance.get_click_upgrade_cost(14) != 110 or balance.get_click_upgrade_cost(15) != 180:
		_fail("Early Click Damage cost stages are incorrect.")
		return
	var save_manager := root.get_node_or_null("SaveManager") as PopSaveManager
	if save_manager == null:
		save_manager = PopSaveManager.new()
		save_manager.name = "SaveManager"
		root.add_child(save_manager)
	save_manager.set_save_path_for_testing(TEST_SAVE_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))

	state.coins = 5
	if not upgrades.try_buy_click_damage() or state.click_damage_level != 2 or state.coins != 0:
		_fail("Click Damage transaction failed.")
		return
	state.coins = 25
	if not equipment.try_buy(&"needle") or state.get_equipment_level(&"needle") != 1 or not is_equal_approx(equipment.get_total_auto_dps(), 1.0):
		_fail("Needle transaction or Auto DPS failed.")
		return
	state.coins = 300
	state.balloon_pops_by_id[&"red_balloon"] = 220
	if not progression.try_unlock_next_balloon() or not state.is_balloon_unlocked(&"blue_balloon") or state.coins != 0:
		_fail("Blue Balloon unlock failed.")
		return
	if not _validate_critical_combo_dart_and_progression(catalog, state, balance, economy, equipment, progression):
		return
	if not _validate_midgame_systems(catalog):
		return
	if not _validate_reveal_requirements(catalog):
		return
	if not await _validate_controller(catalog, state, balance):
		return
	if not await _validate_game_session(catalog, save_manager):
		return
	if not await _validate_main_scene_ui(save_manager):
		return

	state.total_clicks = 51
	state.balloons_popped = 220
	state.coins_earned = 4125
	state.total_damage = 813.0
	state.active_play_seconds = 12
	state.current_normal_balloon_id = &"blue_balloon"
	state.current_balloon_health = 77.0
	state.normal_variation_index = 3
	state.coin_reward_level = 2
	state.diamond_reward_level = 1
	state.buff_frequency_level = 4
	state.buff_frequency_clicks = 342
	state.crystal_balloons_popped = 1
	state.buff_frequency_unlocked = true
	if not save_manager.save_game_state(state, TEST_SAVE_PATH):
		_fail("Save could not be written.")
		return
	var loaded := save_manager.load_game_state(catalog, TEST_SAVE_PATH)
	if loaded == null or loaded.current_normal_balloon_id != &"blue_balloon" or not is_equal_approx(loaded.current_balloon_health, 77.0) or loaded.normal_variation_index != 3 or loaded.get_equipment_level(&"needle") != 1 or loaded.coin_reward_level != 2 or loaded.diamond_reward_level != 1 or loaded.buff_frequency_level != 4 or loaded.buff_frequency_clicks != 342 or loaded.crystal_balloons_popped != 1 or not loaded.buff_frequency_unlocked:
		_fail("Loaded v4 state does not match the saved state.")
		return
	if not _validate_legacy_migrations(catalog, state, save_manager):
		return
	if not _validate_settings_and_recovery(catalog, save_manager):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tests/save_validation_settings.json"))
	print("SAVE_VALIDATION_PASSED")
	quit(0)

func _validate_controller(catalog: ContentCatalogData, state: GameState, balance: BalanceService) -> bool:
	var balloon_container := Control.new()
	balloon_container.size = Vector2(280.0, 360.0)
	root.add_child(balloon_container)
	var controller := BalloonController.new()
	root.add_child(controller)
	controller.setup(catalog, state, balance, load("res://scenes/balloons/balloon.tscn") as PackedScene, balloon_container)
	controller.spawn_current_normal(true)
	await process_frame
	if balloon_container.get_child_count() != 1:
		_fail("BalloonController did not create exactly one balloon.")
		return false
	var balloon := balloon_container.get_child(0) as Balloon
	var local_health_bar := balloon.get_node_or_null("HealthBar") as ProgressBar
	if local_health_bar == null or not is_equal_approx(local_health_bar.value, balloon.get_current_health()):
		_fail("Balloon local health bar was not created or initialized.")
		return false
	controller.damage_current_balloon(AttackResult.new(1.0))
	if balloon.get_current_health() >= balloon.get_max_health() or not is_equal_approx(state.current_balloon_health, balloon.get_current_health()) or not is_equal_approx(local_health_bar.value, balloon.get_current_health()):
		_fail("BalloonController did not preserve current single-balloon health.")
		return false
	controller.damage_current_balloon(AttackResult.new(balloon.get_max_health()))
	await create_timer(0.2).timeout
	if balloon_container.get_child_count() != 1 or state.current_balloon_health <= 0.0:
		_fail("BalloonController did not replace the popped balloon.")
		return false
	controller.set_current_normal_balloon(&"blue_balloon")
	await process_frame
	if (balloon_container.get_child(0) as Balloon).get_balloon_id() != &"blue_balloon":
		_fail("BalloonController did not replace Red with Blue as the current target.")
		return false
	controller.free()
	balloon_container.free()
	return true

func _validate_reveal_requirements(catalog: ContentCatalogData) -> bool:
	var state := GameState.new()
	var reveal_service := RevealService.new(state, catalog)
	reveal_service.initialize()
	if not reveal_service.is_revealed(&"click_damage") or reveal_service.is_revealed(&"needle") or reveal_service.is_revealed(&"critical_chance") or reveal_service.is_revealed(&"dart") or reveal_service.is_revealed(&"combo"):
		_fail("New-game reveal states are incorrect.")
		return false
	state.click_damage_level = 5
	if not reveal_service.refresh().has(&"needle"):
		_fail("Needle did not reveal at Click Damage level 5.")
		return false
	state.unlock_balloon(&"blue_balloon")
	if not reveal_service.refresh().has(&"critical_chance"):
		_fail("Critical Chance did not reveal after Blue.")
		return false
	state.critical_chance_level = 3
	if not reveal_service.refresh().has(&"critical_damage"):
		_fail("Critical Damage did not reveal after Critical Chance level 3.")
		return false
	state.set_equipment_level(&"needle", 10)
	if not reveal_service.refresh().has(&"dart"):
		_fail("Dart did not reveal after Needle level 10.")
		return false
	state.unlock_balloon(&"green_balloon")
	if not reveal_service.refresh().has(&"combo"):
		_fail("Combo did not reveal after Green.")
		return false
	return true

func _validate_critical_combo_dart_and_progression(catalog: ContentCatalogData, state: GameState, balance: BalanceService, economy: EconomyService, equipment: EquipmentService, progression: ProgressionService) -> bool:
	state.click_damage_level = 6
	state.coins = 500
	if not equipment.is_available(&"dart") or not equipment.try_buy(&"dart") or not is_equal_approx(equipment.get_dps(&"dart"), 8.0):
		_fail("Dart did not unlock or contribute Auto DPS after Blue.")
		return false
	state.set_equipment_level(&"dart", 10)
	if not is_equal_approx(equipment.get_dps(&"dart"), 160.0):
		_fail("Dart level 10 milestone did not multiply DPS.")
		return false
	state.set_equipment_level(&"dart", 25)
	if not is_equal_approx(equipment.get_dps(&"dart"), 800.0):
		_fail("Dart level 25 milestone did not stack DPS.")
		return false
	var critical_data := GameBalanceData.new()
	critical_data.click_damage_base = 10.0
	critical_data.critical_chance_per_level = 1.0
	critical_data.critical_damage_base_multiplier = 2.0
	critical_data.critical_damage_bonus_per_level = 0.5
	var critical_state := GameState.new()
	critical_state.critical_chance_level = 1
	critical_state.critical_damage_level = 1
	var critical_attack := CombatResolver.new(BalanceService.new(critical_data)).calculate_manual_attack(critical_state, 1.2)
	if not critical_attack.was_critical or not is_equal_approx(critical_attack.damage, 30.0) or not is_equal_approx(balance.get_combo_multiplier(3), 1.14):
		_fail("Critical or Combo damage calculation failed.")
		return false
	state.coins = 2000
	state.balloon_pops_by_id[&"blue_balloon"] = 180
	if not progression.try_unlock_next_balloon() or not state.is_balloon_unlocked(&"green_balloon"):
		_fail("Green Balloon unlock failed.")
		return false
	state.coins = 20000
	state.balloon_pops_by_id[&"green_balloon"] = 150
	if not progression.try_unlock_next_balloon() or not state.is_balloon_unlocked(&"purple_balloon"):
		_fail("Purple Balloon unlock failed.")
		return false
	return true

func _validate_midgame_systems(catalog: ContentCatalogData) -> bool:
	var state := GameState.new()
	var unlimited_upgrades := UpgradeService.new(state, BalanceService.new(catalog.balance), EconomyService.new(state))
	state.click_damage_level = 200
	if unlimited_upgrades.get_next_click_upgrade_cost() <= 0 or not BalanceService.new(catalog.balance).get_click_milestone_text(200).contains("Lv.200"):
		_fail("Unlimited Click Damage or its milestones failed.")
		return false
	state.click_damage_level = 16
	state.coins = 1000000
	state.click_damage_level = 16
	state.unlock_balloon(&"blue_balloon")
	state.unlock_balloon(&"green_balloon")
	state.unlock_balloon(&"purple_balloon")
	state.set_equipment_level(&"dart", 10)
	var economy := EconomyService.new(state)
	var equipment := EquipmentService.new(state, catalog, BalanceService.new(catalog.balance), economy)
	var reveal := RevealService.new(state, catalog)
	reveal.initialize()
	if not reveal.is_revealed(&"dart_launcher") or not equipment.is_available(&"dart_launcher") or not equipment.try_buy(&"dart_launcher"):
		_fail("Dart Launcher reveal or purchase failed.")
		return false
	state.set_equipment_level(&"dart_launcher", 10)
	state.diamonds = 1
	if not reveal.refresh().has(&"global_upgrades") or not reveal.refresh().has(&"pressure_gun") and not reveal.is_revealed(&"pressure_gun"):
		_fail("Diamond-gated midgame reveal failed.")
		return false
	var globals := GlobalUpgradeService.new(state, catalog, economy)
	if not globals.try_buy(&"auto_dps_core") or not is_equal_approx(globals.get_effect_multiplier(GlobalUpgradeData.Effect.AUTO_DPS), 1.15):
		_fail("Global Upgrade diamond purchase failed.")
		return false
	state.coins = 1000000
	if not equipment.try_buy(&"pressure_gun"):
		_fail("Pressure Gun purchase failed.")
		return false
	state.balloon_pops_by_id[&"purple_balloon"] = 120
	var progression := ProgressionService.new(state, catalog, economy)
	if not progression.can_unlock_next_balloon() or not progression.try_unlock_next_balloon() or not state.is_balloon_unlocked(&"golden_balloon"):
		_fail("Dark Balloon progression failed.")
		return false
	var special := catalog.find_balloon(&"crystal_balloon")
	if special == null or special.category != BalloonData.Category.SPECIAL or special.diamond_reward != 1:
		_fail("Crystal special data failed.")
		return false
	return true

func _validate_game_session(catalog: ContentCatalogData, save_manager: PopSaveManager) -> bool:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	var seeded_state := GameState.new()
	seeded_state.coins = 300
	seeded_state.balloon_pops_by_id[&"red_balloon"] = 220
	if not save_manager.save_game_state(seeded_state, TEST_SAVE_PATH):
		_fail("Could not prepare the GameSession unlock test save.")
		return false
	await process_frame
	var balloon_container := Control.new()
	balloon_container.size = Vector2(280.0, 360.0)
	root.add_child(balloon_container)
	var session := GameSession.new()
	root.add_child(session)
	session.initialize(catalog, load("res://scenes/balloons/balloon.tscn") as PackedScene, balloon_container)
	await process_frame
	if balloon_container.get_child_count() != 1:
		_fail("GameSession did not initialize one active Balloon.")
		return false
	session.request_unlock_next_balloon()
	await process_frame
	if (balloon_container.get_child(0) as Balloon).get_balloon_id() != &"blue_balloon":
		_fail("GameSession did not switch the active target to Blue after its unlock.")
		return false
	session._state.coins = 2000
	session._state.balloon_pops_by_id[&"blue_balloon"] = 180
	session.request_unlock_next_balloon()
	await process_frame
	if (balloon_container.get_child(0) as Balloon).get_balloon_id() != &"green_balloon":
		_fail("GameSession did not switch the active target to Green after its unlock.")
		return false
	var balloon := balloon_container.get_child(0) as Balloon
	var health_before_click := balloon.get_current_health()
	session.handle_balloon_click()
	if balloon.get_current_health() >= health_before_click:
		_fail("GameSession click did not damage the active Balloon.")
		return false
	session.handle_balloon_click()
	if session.get_combo_stacks() != 2 or not is_equal_approx(session.get_combo_multiplier(), 1.07):
		_fail("GameSession did not build Combo from repeated clicks.")
		return false
	await create_timer(1.6).timeout
	if session.get_combo_stacks() != 0:
		_fail("GameSession did not reset Combo after its timeout.")
		return false
	var coins_before_pop := session.get_coins()
	var expected_reward := catalog.find_balloon(balloon.get_balloon_id()).coin_reward
	balloon.take_damage(AttackResult.new(balloon.get_max_health()))
	await create_timer(0.2).timeout
	if session.get_coins() != coins_before_pop + expected_reward or balloon_container.get_child_count() != 1:
		_fail("GameSession did not reward and replace the active Balloon.")
		return false
	session.free()
	balloon_container.free()
	return true

func _validate_legacy_migrations(catalog: ContentCatalogData, state: GameState, save_manager: PopSaveManager) -> bool:
	var legacy_v3 := state.to_save_data()
	legacy_v3["save_version"] = 3
	legacy_v3.erase("global_upgrade_levels")
	var v3_file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	v3_file.store_string(JSON.stringify(legacy_v3))
	v3_file.close()
	var migrated_v3 := save_manager.load_game_state(catalog, TEST_SAVE_PATH)
	if migrated_v3 == null or migrated_v3.get_global_upgrade_level(&"auto_dps_core") != 0:
		_fail("Version 3 global upgrade migration failed.")
		return false
	var legacy_v1 := state.to_save_data()
	legacy_v1["save_version"] = 1
	var v1_file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	v1_file.store_string(JSON.stringify(legacy_v1))
	v1_file.close()
	var migrated_v1 := save_manager.load_game_state(catalog, TEST_SAVE_PATH)
	if migrated_v1 == null or migrated_v1.current_normal_balloon_id != &"blue_balloon" or not is_equal_approx(migrated_v1.current_balloon_health, 77.0):
		_fail("Version 1 save migration failed.")
		return false
	var legacy_v2 := state.to_save_data()
	legacy_v2["save_version"] = 2
	var progression: Dictionary = legacy_v2["progression"]
	progression.erase("current_normal_balloon_id")
	progression.erase("current_balloon_health")
	progression.erase("normal_variation_index")
	legacy_v2["progression"] = progression
	var v2_file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	v2_file.store_string(JSON.stringify(legacy_v2))
	v2_file.close()
	var migrated_v2 := save_manager.load_game_state(catalog, TEST_SAVE_PATH)
	if migrated_v2 == null or migrated_v2.current_normal_balloon_id != &"purple_balloon" or migrated_v2.current_balloon_health != 0.0:
		_fail("Version 2 field save migration failed.")
		return false
	return true

func _validate_settings_and_recovery(catalog: ContentCatalogData, save_manager: PopSaveManager) -> bool:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tests/save_validation_settings.json"))
	if not save_manager.save_audio_settings(0.61, 0.42, 0.83, TEST_SAVE_PATH):
		_fail("Audio preferences could not be written.")
		return false
	if not save_manager.save_display_settings(true, false, TEST_SAVE_PATH):
		_fail("Display preferences could not be written.")
		return false
	var audio := save_manager.load_audio_settings(TEST_SAVE_PATH)
	var display := save_manager.load_display_settings(TEST_SAVE_PATH)
	if not is_equal_approx(float(audio.get("master_volume", -1.0)), 0.61) or not is_equal_approx(float(audio.get("music_volume", -1.0)), 0.42) or not is_equal_approx(float(audio.get("sfx_volume", -1.0)), 0.83) or not bool(display.get("fullscreen", false)) or bool(display.get("vsync", true)):
		_fail("Audio and display preferences were not preserved together.")
		return false
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_fail("Could not prepare malformed-save recovery test.")
		return false
	file.store_string("{ malformed")
	file.close()
	var recovered := save_manager.load_game_state(catalog, TEST_SAVE_PATH)
	if recovered == null or not is_equal_approx(recovered.master_volume, 0.61) or not is_equal_approx(recovered.music_volume, 0.42) or not is_equal_approx(recovered.sfx_volume, 0.83) or not save_manager.requires_recovery():
		_fail("Malformed save recovery did not preserve preferences or protect the campaign file.")
		return false
	if save_manager.save_game_state(recovered, TEST_SAVE_PATH):
		_fail("Malformed save was overwritten without explicit New Game confirmation.")
		return false
	if not save_manager.reset_save_confirmed(recovered, TEST_SAVE_PATH):
		_fail("Confirmed New Game recovery could not replace malformed save.")
		return false
	return true

func _validate_main_scene_ui(save_manager: PopSaveManager) -> bool:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	var seeded_state := GameState.new()
	seeded_state.coins = 1000
	if not save_manager.save_game_state(seeded_state, TEST_SAVE_PATH):
		_fail("Could not prepare the HUD interaction test save.")
		return false
	var game_scene := load("res://scenes/main/game.tscn") as PackedScene
	var game := game_scene.instantiate() as Game
	root.add_child(game)
	await process_frame
	var hud := game.get_node_or_null("UI/MainHUD") as MainHud
	if hud == null or not hud.visible:
		_fail("Main HUD could not be created.")
		return false
	if hud.get_node_or_null("Margin/Layout/HealthPanel") != null:
		_fail("Main HUD still contains a global health panel.")
		return false
	var click_button := hud._click_upgrade_button
	if click_button == null:
		_fail("Main HUD Click Damage button could not be created.")
		return false
	if click_button.disabled:
		_fail("Click Damage button is disabled with sufficient Coins.")
		return false
	var needle_button := hud._needle_button
	if needle_button == null or needle_button.visible:
		_fail("Needle is visible before its reveal requirement.")
		return false
	var top_bar := hud.get_node_or_null("Margin/Layout/TopBar") as Control
	var cards := hud.get_node_or_null("Margin/Layout/Body/Shop") as Control
	if top_bar == null or cards == null or top_bar.get_global_rect().position.y < hud.get_global_rect().position.y or cards.get_global_rect().end.y > hud.get_global_rect().end.y:
		_fail("Main HUD layout exceeds the game viewport.")
		return false
	click_button.pressed.emit()
	await process_frame
	var click_label := hud._click_damage_label
	if click_label == null or hud._session._state.click_damage_level != 2 or click_label.text.contains("Lv."):
		_fail("Main HUD Click Damage button did not trigger its upgrade.")
		return false
	for _index in 3:
		click_button.pressed.emit()
		await process_frame
	if not needle_button.visible:
		_fail("Needle did not appear in the HUD after Click Damage level 5.")
		return false
	game.free()
	await process_frame
	return true

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
