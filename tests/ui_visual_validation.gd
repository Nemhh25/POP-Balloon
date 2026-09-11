extends SceneTree

const PATH := "res://tests/ui_visual_save.json"
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var save := root.get_node("SaveManager") as PopSaveManager
	save.set_save_path_for_testing(PATH)
	var catalog := load("res://data/content_catalog.tres") as ContentCatalogData
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/ui_captures"))
	for scenario in ["fresh", "purple", "rainbow", "global", "buff", "small", "wide", "boss", "victory"]:
		root.mode = Window.MODE_FULLSCREEN if scenario == "wide" else Window.MODE_WINDOWED
		root.size = Vector2i(1100, 650) if scenario == "small" else Vector2i(1920, 1080) if scenario == "wide" else Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		var state := GameState.new()
		if scenario != "fresh":
			for data: BalloonData in catalog.balloons:
				if data.category == BalloonData.Category.NORMAL and data.tier_index <= (4 if scenario == "purple" else 6):
					state.unlock_balloon(data.id)
					state.balloon_pops_by_id[data.id] = 100
			state.current_normal_balloon_id = &"purple_balloon" if scenario == "purple" else &"rainbow_balloon"
			state.click_damage_level = 34
			state.critical_chance_level = 42
			state.critical_damage_level = 5
			state.coins = 28606000
			state.diamonds = 12
			state.buff_frequency_unlocked = true
			state.buff_frequency_clicks = 342
			state.buff_frequency_level = 9
			state.crystal_balloons_popped = 1
			for item: EquipmentData in catalog.equipment:
				state.set_equipment_level(item.id, 10)
		save.save_game_state(state)
		var game := load("res://scenes/main/game.tscn").instantiate() as Game
		root.add_child(game)
		await create_timer(0.3).timeout
		var hud := game._main_hud
		if scenario != "fresh":
			game._game_session._buffs.activate(&"electric", 2.0, 12.0)
			hud._on_combo_changed(12, 1.77)
		if scenario in ["rainbow", "small", "wide"]: hud._tabs.current_tab = 1
		if scenario == "global": hud._tabs.current_tab = 2
		if scenario == "buff":
			hud._tabs.current_tab = 0
			(hud._tabs.get_child(0) as ScrollContainer).scroll_vertical = 1500
		if scenario == "boss": game._game_session.request_unlock_next_balloon()
		if scenario == "victory": hud._on_victory_requested()
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/ui_captures/%s.png" % scenario)
		var bounds := hud.get_global_rect()
		if not bounds.encloses(hud._tabs.get_global_rect()): failures.append(scenario + ": shop overflow")
		if hud._unlock_balloon_button.is_visible_in_tree() and not bounds.encloses(hud._unlock_balloon_button.get_global_rect()): failures.append(scenario + ": progression overflow")
		if game._balloon_container.get_global_rect().intersects(hud._tabs.get_global_rect()): failures.append(scenario + ": balloon overlaps shop")
		if hud._unlock_balloon_button.is_visible_in_tree() and game._balloon_container.get_global_rect().intersects(hud._unlock_balloon_button.get_global_rect()): failures.append(scenario + ": balloon overlaps progression")
		print(scenario, " stage=", game._balloon_container.get_global_rect(), " shop=", hud._tabs.get_global_rect())
		game.free()
		await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("VISUAL_LAYOUT_RESULTS: ", failures)
	quit(0 if failures.is_empty() else 1)
