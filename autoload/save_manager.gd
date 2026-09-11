class_name PopSaveManager
extends Node

const SAVE_PATH := "user://pop_balloon_save.json"
const SETTINGS_PATH := "user://pop_balloon_settings.json"

var _save_blocked_by_invalid_data := false
var _runtime_save_path := SAVE_PATH

func _ready() -> void:
	var display_settings := load_display_settings()
	apply_display_settings(bool(display_settings["fullscreen"]), bool(display_settings["vsync"]))

func has_valid_save(catalog: ContentCatalogData, save_path: String = "") -> bool:
	var resolved_path := _resolve_save_path(save_path)
	if not FileAccess.file_exists(resolved_path):
		return false
	var file := FileAccess.open(resolved_path, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return false
	return GameState.from_save_data(json.data, catalog) != null

func has_save_file(save_path: String = "") -> bool:
	return FileAccess.file_exists(_resolve_save_path(save_path))

func load_game_state(catalog: ContentCatalogData, save_path: String = "") -> GameState:
	var resolved_path := _resolve_save_path(save_path)
	if not FileAccess.file_exists(resolved_path):
		var fresh_state := GameState.new()
		_apply_audio_settings(fresh_state, load_audio_settings(save_path))
		_apply_gameplay_settings(fresh_state, _load_settings_data(save_path))
		return fresh_state
	var file := FileAccess.open(resolved_path, FileAccess.READ)
	if file == null:
		_mark_invalid_save("could not be opened")
		return _new_state_with_preferences(save_path)
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		_mark_invalid_save("contains malformed JSON")
		return _new_state_with_preferences(save_path)
	var loaded_state := GameState.from_save_data(json.data, catalog)
	if loaded_state == null:
		_mark_invalid_save("has an unsupported version or invalid data")
		return _new_state_with_preferences(save_path)
	_apply_audio_settings(loaded_state, load_audio_settings(save_path))
	_apply_gameplay_settings(loaded_state, _load_settings_data(save_path))
	return loaded_state

func save_game_state(state: GameState, save_path: String = "") -> bool:
	var resolved_path := _resolve_save_path(save_path)
	if _save_blocked_by_invalid_data:
		push_warning("Save was not overwritten because recovery is required for the existing invalid save.")
		return false
	var file := FileAccess.open(resolved_path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to open POP Balloon save for writing: %s" % resolved_path)
		return false
	file.store_string(JSON.stringify(state.to_save_data(), "\t"))
	if file.get_error() != OK:
		push_error("Unable to write POP Balloon save: %s" % resolved_path)
		return false
	return true

func reset_save_confirmed(state: GameState, save_path: String = "") -> bool:
	_save_blocked_by_invalid_data = false
	return save_game_state(state, save_path)

func load_audio_settings(save_path: String = "") -> Dictionary:
	var data := _load_settings_data(save_path)
	if not _is_valid_volume(data.get("master_volume")) or not _is_valid_volume(data.get("music_volume")) or not _is_valid_volume(data.get("sfx_volume")):
		return {}
	return data

func save_audio_settings(master: float, music: float, sfx: float, save_path: String = "") -> bool:
	var data := _load_settings_data(save_path)
	data["master_volume"] = clampf(master, 0.0, 1.0)
	data["music_volume"] = clampf(music, 0.0, 1.0)
	data["sfx_volume"] = clampf(sfx, 0.0, 1.0)
	return _save_settings_data(data, save_path)

func load_display_settings(save_path: String = "") -> Dictionary:
	var data := _load_settings_data(save_path)
	return {
		"fullscreen": bool(data.get("fullscreen", false)),
		"vsync": bool(data.get("vsync", true)),
	}

func save_display_settings(fullscreen: bool, vsync: bool, save_path: String = "") -> bool:
	var data := _load_settings_data(save_path)
	data["fullscreen"] = fullscreen
	data["vsync"] = vsync
	return _save_settings_data(data, save_path)

func save_hold_click_setting(enabled: bool, save_path: String = "") -> bool:
	var data := _load_settings_data(save_path)
	data["hold_click_enabled"] = enabled
	return _save_settings_data(data, save_path)

func apply_display_settings(fullscreen: bool, vsync: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

func _load_settings_data(save_path: String = "") -> Dictionary:
	var path := _resolve_settings_path(save_path)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data as Dictionary

func _save_settings_data(data: Dictionary, save_path: String = "") -> bool:
	var file := FileAccess.open(_resolve_settings_path(save_path), FileAccess.WRITE)
	if file == null:
		push_error("Unable to write POP Balloon settings.")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return file.get_error() == OK

func requires_recovery() -> bool:
	return _save_blocked_by_invalid_data

func set_save_path_for_testing(save_path: String) -> void:
	_runtime_save_path = save_path

func _resolve_save_path(save_path: String) -> String:
	return _runtime_save_path if save_path.is_empty() else save_path

func _resolve_settings_path(save_path: String) -> String:
	var save_path_resolved := _resolve_save_path(save_path)
	return SETTINGS_PATH if save_path_resolved == SAVE_PATH else "%s_settings.json" % save_path_resolved.get_basename()

func _apply_audio_settings(state: GameState, settings: Dictionary) -> void:
	if settings.is_empty():
		return
	state.master_volume = float(settings["master_volume"])
	state.music_volume = float(settings["music_volume"])
	state.sfx_volume = float(settings["sfx_volume"])

func _apply_gameplay_settings(state: GameState, settings: Dictionary) -> void:
	if settings.has("hold_click_enabled"):
		state.hold_click_enabled = bool(settings["hold_click_enabled"])

func _new_state_with_preferences(save_path: String) -> GameState:
	var state := GameState.new()
	_apply_audio_settings(state, load_audio_settings(save_path))
	_apply_gameplay_settings(state, _load_settings_data(save_path))
	return state

func _is_valid_volume(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and float(value) >= 0.0 and float(value) <= 1.0

func _mark_invalid_save(reason: String) -> void:
	_save_blocked_by_invalid_data = true
	push_error("POP Balloon save %s. The file was preserved and will not be overwritten automatically." % reason)
