extends SceneTree

const TEST_SAVE_PATH := "res://tests/menu_validation_save.json"
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_manager := root.get_node("SaveManager") as PopSaveManager
	var catalog := load("res://data/content_catalog.tres") as ContentCatalogData
	save_manager.set_save_path_for_testing(TEST_SAVE_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tests/menu_validation_save_settings.json"))
	var fresh_menu := await _create_menu()
	if fresh_menu._continue_button.visible:
		failures.append("Continue is visible without a save.")
	if fresh_menu._endless_button.visible:
		failures.append("Endless is visible before unlock.")
	fresh_menu._master_slider.value = 61.0
	await process_frame
	fresh_menu.free()
	var reopened_settings_menu := await _create_menu()
	if not is_equal_approx(reopened_settings_menu._master_slider.value, 61.0):
		failures.append("Audio settings do not persist without a campaign save.")
	reopened_settings_menu.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tests/menu_validation_save_settings.json"))

	var completed := GameState.new()
	completed.master_volume = 0.72
	completed.music_volume = 0.53
	completed.sfx_volume = 0.81
	completed.campaign_completed = true
	completed.endless_unlocked = true
	if not save_manager.save_game_state(completed):
		failures.append("Could not prepare menu save.")
	else:
		var saved_menu := await _create_menu()
		if not saved_menu._continue_button.visible:
			failures.append("Continue is hidden with a valid save.")
		if not saved_menu._endless_button.visible or not saved_menu._campaign_complete.visible:
			failures.append("Completed campaign indicators are missing.")
		if not is_equal_approx(saved_menu._master_slider.value, 72.0):
			failures.append("Saved audio settings were not loaded.")
		saved_menu._master_slider.value = 64.0
		await process_frame
		var persisted := save_manager.load_game_state(catalog)
		if not is_equal_approx(persisted.master_volume, 0.64):
			failures.append("Menu audio settings were not persisted.")
		saved_menu._request_new_game()
		if not saved_menu._confirmation.visible:
			failures.append("New Game did not ask for confirmation.")
		saved_menu._confirmation.hide()
		saved_menu.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tests/menu_validation_save_settings.json"))
	print("MENU_VALIDATION_RESULTS: ", failures)
	quit(0 if failures.is_empty() else 1)

func _create_menu() -> MainMenu:
	var menu := load("res://scenes/main/main_menu.tscn").instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	return menu
