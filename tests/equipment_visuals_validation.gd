extends SceneTree

var failures: Array[String] = []
const SAVE := "res://tests/equipment_visuals_save.json"

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	create_timer(15.0).timeout.connect(func() -> void: quit(2))
	var catalog := load("res://data/content_catalog.tres") as ContentCatalogData
	var save := root.get_node("SaveManager") as PopSaveManager
	save.set_save_path_for_testing(SAVE)
	var state := GameState.new()
	state.coins = 100000
	state.unlock_balloon(&"blue_balloon")
	for id: StringName in [&"needle", &"dart", &"dart_launcher", &"pressure_gun"]:
		state.set_equipment_level(id, 1)
	check(save.save_game_state(state), "Seed visual test save")
	var game := load("res://scenes/main/game.tscn").instantiate() as Game
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	var effects := game._balloon_container.get_node_or_null("BalloonVisualEffects") as BalloonVisualEffects
	check(effects != null, "Equipment visual layer was not created")
	if effects != null:
		check(not effects._effects.is_empty(), "Owned equipment did not create field sprites")
		game._game_session.auto_attack_performed.emit()
		var animated := false
		for effect: Dictionary in effects._effects:
			animated = animated or effects._is_effect_attacking(effect)
		check(animated, "Auto DPS did not start an equipment animation")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE.get_basename() + "_settings.json"))
	print("EQUIPMENT_VISUALS_RESULTS: ", failures)
	quit(0 if failures.is_empty() else 1)
