extends SceneTree

const PATH := "res://tests/audio_validation_save.json"
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> void:
	var audio: Variant = root.get_node_or_null("AudioManager")
	check(audio != null, "AudioManager autoload missing")
	for bus in [&"Music", &"SFX", &"UI"]:
		check(AudioServer.get_bus_index(bus) >= 0, "Missing audio bus: %s" % bus)
	check(audio._sfx_players.size() == 6 and audio._ui_players.size() == 3, "Audio pools changed")
	check(audio._streams.has(&"menu") and audio._streams.has(&"gameplay") and audio._streams.has(&"boss") and audio._streams.has(&"victory"), "Music states missing")
	check(audio._streams[&"menu"] is AudioStreamOggVorbis and audio._streams[&"gameplay"] is AudioStreamOggVorbis, "External music themes were not assigned")
	check(audio._streams[&"menu"].loop and audio._streams[&"gameplay"].loop, "Music themes do not loop")
	check(audio._streams[&"boss"] is AudioStreamOggVorbis and audio._streams[&"boss"].loop, "Balloon King theme is missing or does not loop")
	for pop_id: StringName in audio.POP_VARIATION_IDS:
		check(audio._streams.has(pop_id) and audio._streams[pop_id] is AudioStreamOggVorbis, "Missing pop variation: %s" % pop_id)
	audio.play_menu_music()
	check(audio._music_state == &"menu", "Menu music did not start")
	audio.play_menu_music()
	check(audio._music_state == &"menu", "Menu music restarted unexpectedly")
	audio.play_gameplay_music()
	check(audio._music_state == &"gameplay", "Gameplay music did not start")
	var pop_counts := {}
	for _index in 90:
		for player: AudioStreamPlayer in audio._sfx_players:
			player.stop()
		var selected: StringName = audio.play_pop()
		pop_counts[selected] = int(pop_counts.get(selected, 0)) + 1
		for player: AudioStreamPlayer in audio._sfx_players:
			if player.playing:
				check(player.pitch_scale >= 0.96 and player.pitch_scale <= 1.04, "Pop pitch is outside the requested range")
				break
		audio._last_played[selected] = -999.0
	for pop_id: StringName in audio.POP_VARIATION_IDS:
		check(int(pop_counts.get(pop_id, 0)) > 0, "Pop variation was never selected: %s" % pop_id)
	audio.start_boss_music()
	check(audio._music_state == &"boss", "Balloon King theme did not start")
	audio.start_boss_music()
	check(audio._music_state == &"boss", "Balloon King theme restarted unexpectedly")
	audio.play_boss_phase()
	check(audio._music_state == &"boss", "Boss phase changed the active boss theme")
	audio.play_boss_victory()
	check(audio._music_state == &"victory", "Boss victory did not transition to the existing victory state")
	audio.play_manual_hit()
	audio.play_critical()
	audio.play_pop()
	audio.play_purchase(true)
	audio.play_diamond()
	audio.start_boss_music()
	audio.play_boss_victory()
	await create_timer(0.05).timeout
	check(audio._sfx_players.filter(func(player: AudioStreamPlayer) -> bool: return player.playing).size() <= 6, "SFX pool overflow")
	var save := root.get_node("SaveManager") as PopSaveManager
	save.set_save_path_for_testing(PATH)
	var catalog := load("res://data/content_catalog.tres") as ContentCatalogData
	var state := GameState.new()
	state.master_volume = 0.35
	state.music_volume = 0.45
	state.sfx_volume = 0.55
	check(save.save_game_state(state), "Could not save audio settings")
	var loaded := save.load_game_state(catalog)
	check(is_equal_approx(loaded.master_volume, 0.35) and is_equal_approx(loaded.music_volume, 0.45) and is_equal_approx(loaded.sfx_volume, 0.55), "Audio settings did not persist")
	var game := load("res://scenes/main/game.tscn").instantiate() as Game
	root.add_child(game)
	await create_timer(0.12).timeout
	var hud := game._main_hud
	hud._settings_button.pressed.emit()
	check(hud._audio_settings_panel.visible, "Audio settings panel did not open")
	hud._master_slider.value = 35.0
	hud._music_slider.value = 45.0
	hud._sfx_slider.value = 55.0
	await process_frame
	check(is_equal_approx(game._game_session._state.master_volume, 0.35) and is_equal_approx(game._game_session._state.music_volume, 0.45) and is_equal_approx(game._game_session._state.sfx_volume, 0.55), "Slider settings did not apply")
	audio._last_played.erase(&"hit")
	game._game_session._hold_click_timer.timeout.emit()
	check(audio._last_played.has(&"hit"), "Hold click attack did not emit the manual hit sound")
	game.free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("AUDIO_VALIDATION_RESULTS: ", failures)
	quit(0 if failures.is_empty() else 1)
