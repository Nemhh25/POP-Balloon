extends SceneTree

const PATH := "res://tests/music_flow_validation_save.json"
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_manager := root.get_node("SaveManager") as PopSaveManager
	var audio: Variant = root.get_node("AudioManager")
	save_manager.set_save_path_for_testing(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tests/music_flow_validation_save_settings.json"))

	var menu := load("res://scenes/main/main_menu.tscn").instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	_check(audio._music_state == &"menu", "Menu music did not start on entry.")
	menu._show_settings()
	_check(audio._music_state == &"menu", "Settings restarted or replaced menu music.")
	menu._show_credits()
	_check(audio._music_state == &"menu", "Credits restarted or replaced menu music.")
	menu._show_main()
	menu._start_game(PopGameFlow.LaunchMode.NEW_GAME)
	await create_timer(0.35).timeout
	_check(current_scene is Game, "New Game did not enter gameplay.")
	_check(audio._music_state == &"gameplay", "Gameplay music did not start after New Game.")
	if current_scene is Game:
		(current_scene as Game)._game_session._state.endless_unlocked = true
		(current_scene as Game)._return_to_main_menu()
		await create_timer(0.35).timeout
	_check(current_scene is MainMenu, "Gameplay did not return to Main Menu.")
	_check(audio._music_state == &"menu", "Menu music did not resume after gameplay.")
	if current_scene is MainMenu:
		(current_scene as MainMenu)._start_game(PopGameFlow.LaunchMode.CONTINUE_CAMPAIGN)
		await create_timer(0.35).timeout
	_check(current_scene is Game and audio._music_state == &"gameplay", "Continue did not start gameplay music.")
	if current_scene is Game:
		(current_scene as Game)._return_to_main_menu()
		await create_timer(0.35).timeout
	if current_scene is MainMenu:
		(current_scene as MainMenu)._start_game(PopGameFlow.LaunchMode.ENDLESS)
		await create_timer(0.35).timeout
	_check(current_scene is Game and audio._music_state == &"gameplay", "Endless did not start gameplay music.")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tests/music_flow_validation_save_settings.json"))
	print("MUSIC_FLOW_VALIDATION_RESULTS: ", failures)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
