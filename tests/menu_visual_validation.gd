extends SceneTree

const PATH := "res://tests/menu_visual_save.json"
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_manager := root.get_node("SaveManager") as PopSaveManager
	save_manager.set_save_path_for_testing(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tests/menu_visual_save_settings.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/ui_captures"))
	for size in [Vector2i(1280, 720), Vector2i(1100, 650), Vector2i(1920, 1080)]:
		root.size = size
		root.content_scale_size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		var menu := load("res://scenes/main/main_menu.tscn").instantiate() as MainMenu
		root.add_child(menu)
		await create_timer(0.2).timeout
		if not menu.get_global_rect().encloses(menu._menu_panel.get_global_rect()):
			failures.append("menu panel overflow at %s" % size)
		if not menu.get_global_rect().encloses(menu._new_game_button.get_global_rect()):
			failures.append("new game button overflow at %s" % size)
		if menu._menu_panel.get_global_rect().intersects(menu._confirmation.get_global_rect()) and menu._confirmation.visible:
			failures.append("unexpected confirmation at %s" % size)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/ui_captures/menu_%dx%d.png" % [size.x, size.y])
		menu.free()
		await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tests/menu_visual_save_settings.json"))
	print("MENU_VISUAL_RESULTS: ", failures)
	quit(0 if failures.is_empty() else 1)
