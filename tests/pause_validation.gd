extends SceneTree

const PATH := "res://tests/pause_validation_save.json"
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_manager := root.get_node("SaveManager") as PopSaveManager
	save_manager.set_save_path_for_testing(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var game := load("res://scenes/main/game.tscn").instantiate() as Game
	root.add_child(game)
	await process_frame
	game._main_hud.toggle_pause()
	if not paused or not game._main_hud._pause_overlay.visible:
		failures.append("Pause overlay did not pause the game.")
	if game._game_session._auto_damage_timer.process_mode == Node.PROCESS_MODE_ALWAYS:
		failures.append("Gameplay timer is incorrectly allowed while paused.")
	game._main_hud._resume_game()
	if paused or game._main_hud._pause_overlay.visible:
		failures.append("Resume did not restore gameplay.")
	game._main_hud.toggle_pause()
	game._main_hud._open_pause_settings()
	if game._main_hud._audio_settings_panel == null or not game._main_hud._audio_settings_panel.visible:
		failures.append("Pause Settings did not open audio settings.")
	game._main_hud._resume_game()
	game._main_hud._return_to_main_menu()
	await create_timer(0.3).timeout
	if not (current_scene is MainMenu):
		failures.append("Main Menu action did not change scenes.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tests/pause_validation_save_settings.json"))
	print("PAUSE_VALIDATION_RESULTS: ", failures)
	quit(0 if failures.is_empty() else 1)
