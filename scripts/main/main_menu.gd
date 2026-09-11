class_name MainMenu
extends Control

@export var content_catalog: ContentCatalogData

@onready var _continue_button: Button = %ContinueButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _endless_button: Button = %EndlessButton
@onready var _settings_button: Button = %SettingsButton
@onready var _credits_button: Button = %CreditsButton
@onready var _quit_button: Button = %QuitButton
@onready var _campaign_complete: Label = %CampaignComplete
@onready var _menu_panel: PanelContainer = %MenuPanel
@onready var _settings_panel: PanelContainer = %SettingsPanel
@onready var _credits_panel: PanelContainer = %CreditsPanel
@onready var _confirmation: ColorRect = %Confirmation
@onready var _fade: ColorRect = %Fade
@onready var _credits_text: Label = %CreditsText
@onready var _master_slider: HSlider = %MasterSlider
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _master_value: Label = %MasterValue
@onready var _music_value: Label = %MusicValue
@onready var _sfx_value: Label = %SfxValue
@onready var _fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var _vsync_toggle: CheckButton = %VSyncToggle
@onready var _version_label: Label = %VersionLabel

var _save_manager: PopSaveManager
var _loaded_state: GameState
var _has_valid_save := false
var _transitioning := false

func _ready() -> void:
	theme = preload("res://scripts/ui/pop_theme.gd").build()
	_save_manager = get_node_or_null("/root/SaveManager") as PopSaveManager
	assert(_save_manager != null, "SaveManager autoload is required.")
	_refresh_save_state()
	_localize_text()
	_credits_text.text = PopCredits.get_text()
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.9.0-playtest")
	_configure_buttons()
	_configure_settings()
	_show_main()
	_fade.color.a = 1.0
	move_child(_fade, get_child_count() - 1)
	var intro := create_tween()
	intro.tween_property(_fade, "color:a", 0.0, 0.22)
	%Title.pivot_offset = %Title.size * 0.5
	%Title.scale = Vector2.ONE * 0.9
	var title_tween := create_tween()
	title_tween.tween_property(%Title, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var audio: Variant = get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_menu_music()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and (_settings_panel.visible or _credits_panel.visible):
		_show_main()
		get_viewport().set_input_as_handled()

func _configure_buttons() -> void:
	_continue_button.visible = _has_valid_save
	_endless_button.visible = _has_valid_save and _loaded_state.endless_unlocked
	_campaign_complete.visible = _has_valid_save and _loaded_state.campaign_completed
	_continue_button.pressed.connect(func() -> void: _start_game(PopGameFlow.LaunchMode.CONTINUE_CAMPAIGN))
	_new_game_button.pressed.connect(_request_new_game)
	_endless_button.pressed.connect(func() -> void: _start_game(PopGameFlow.LaunchMode.ENDLESS))
	_settings_button.pressed.connect(_show_settings)
	_credits_button.pressed.connect(_show_credits)
	_quit_button.pressed.connect(get_tree().quit)
	%SettingsBackButton.pressed.connect(_show_main)
	%CreditsBackButton.pressed.connect(_show_main)
	%ConfirmCancelButton.pressed.connect(_hide_confirmation)
	%ConfirmNewGameButton.pressed.connect(_confirm_new_game)
	var buttons := [_continue_button, _new_game_button, _endless_button, _settings_button, _credits_button, _quit_button, %SettingsBackButton, %CreditsBackButton, %ConfirmCancelButton, %ConfirmNewGameButton]
	for button: Button in buttons:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_play_menu_click)
	_new_game_button.grab_focus()

func _localize_text() -> void:
	%Title.text = tr("POP BALLOON")
	%MenuPanel.get_node("Layout/Subtitle").text = tr("POP. UPGRADE. GO HIGHER.")
	%CampaignComplete.text = tr("Campaign Complete")
	_continue_button.text = tr("Continue")
	_new_game_button.text = tr("New Game")
	_endless_button.text = tr("Endless Mode")
	_settings_button.text = tr("Settings")
	_credits_button.text = tr("Credits")
	_quit_button.text = tr("Quit")
	%SettingsBackButton.text = tr("Back")
	%CreditsBackButton.text = tr("Back")
	%ConfirmCancelButton.text = tr("Cancel")
	%ConfirmNewGameButton.text = tr("New Game")
	%Confirmation.get_node("Center/Panel/Layout/Title").text = tr("Start a new game?")
	%Confirmation.get_node("Center/Panel/Layout/Message").text = tr("Your current progress will be reset.")
	%SettingsPanel.get_node("Layout/Title").text = tr("Settings")
	%SettingsPanel.get_node("Layout/MasterRow/Label").text = tr("Master Volume")
	%SettingsPanel.get_node("Layout/MusicRow/Label").text = tr("Music Volume")
	%SettingsPanel.get_node("Layout/SfxRow/Label").text = tr("SFX Volume")
	_fullscreen_toggle.text = tr("Fullscreen")
	_vsync_toggle.text = tr("VSync")
	%CreditsPanel.get_node("Layout/Title").text = tr("Credits")

func _configure_settings() -> void:
	var state := _loaded_state if _loaded_state != null else GameState.new()
	_master_slider.set_value_no_signal(state.master_volume * 100.0)
	_music_slider.set_value_no_signal(state.music_volume * 100.0)
	_sfx_slider.set_value_no_signal(state.sfx_volume * 100.0)
	for slider in [_master_slider, _music_slider, _sfx_slider]:
		slider.value_changed.connect(func(_value: float) -> void: _apply_audio_settings())
	var display_settings := _save_manager.load_display_settings()
	_fullscreen_toggle.set_pressed_no_signal(bool(display_settings["fullscreen"]))
	_vsync_toggle.set_pressed_no_signal(bool(display_settings["vsync"]))
	_fullscreen_toggle.toggled.connect(_apply_display_settings)
	_vsync_toggle.toggled.connect(_apply_display_settings)
	_update_volume_labels()
	var audio: Variant = get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.apply_settings(state.master_volume, state.music_volume, state.sfx_volume)

func _refresh_save_state() -> void:
	_has_valid_save = _save_manager.has_valid_save(content_catalog)
	_loaded_state = _save_manager.load_game_state(content_catalog)

func _request_new_game() -> void:
	if _save_manager.has_save_file():
		_confirmation.show()
		%ConfirmNewGameButton.grab_focus()
		return
	_confirm_new_game()

func _confirm_new_game() -> void:
	var fresh_state := GameState.new()
	if _has_valid_save:
		fresh_state.master_volume = _loaded_state.master_volume
		fresh_state.music_volume = _loaded_state.music_volume
		fresh_state.sfx_volume = _loaded_state.sfx_volume
	if _save_manager.has_save_file() and not _save_manager.reset_save_confirmed(fresh_state):
		return
	_loaded_state = fresh_state
	_has_valid_save = true
	_hide_confirmation()
	_start_game(PopGameFlow.LaunchMode.NEW_GAME)

func _start_game(mode: PopGameFlow.LaunchMode) -> void:
	if _transitioning:
		return
	_transitioning = true
	var flow := get_node_or_null("/root/GameFlow") as PopGameFlow
	if flow != null:
		match mode:
			PopGameFlow.LaunchMode.NEW_GAME: flow.start_new_game()
			PopGameFlow.LaunchMode.ENDLESS: flow.start_endless()
			_: flow.start_campaign()
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.18)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/main/game.tscn")

func _show_main() -> void:
	_menu_panel.show()
	_settings_panel.hide()
	_credits_panel.hide()
	_confirmation.hide()
	_new_game_button.grab_focus()

func _show_settings() -> void:
	_menu_panel.hide()
	_settings_panel.show()
	_settings_panel.modulate.a = 0.0
	create_tween().tween_property(_settings_panel, "modulate:a", 1.0, 0.12)
	%SettingsBackButton.grab_focus()

func _show_credits() -> void:
	_menu_panel.hide()
	_credits_panel.show()
	_credits_panel.modulate.a = 0.0
	create_tween().tween_property(_credits_panel, "modulate:a", 1.0, 0.12)
	%CreditsBackButton.grab_focus()

func _hide_confirmation() -> void:
	_confirmation.hide()
	_new_game_button.grab_focus()

func _apply_audio_settings() -> void:
	_update_volume_labels()
	var audio: Variant = get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.apply_settings(_master_slider.value / 100.0, _music_slider.value / 100.0, _sfx_slider.value / 100.0)
	if _loaded_state != null:
		_loaded_state.master_volume = _master_slider.value / 100.0
		_loaded_state.music_volume = _music_slider.value / 100.0
		_loaded_state.sfx_volume = _sfx_slider.value / 100.0
		_save_manager.save_audio_settings(_loaded_state.master_volume, _loaded_state.music_volume, _loaded_state.sfx_volume)
		if _has_valid_save:
			_save_manager.save_game_state(_loaded_state)

func _update_volume_labels() -> void:
	_master_value.text = "%d%%" % roundi(_master_slider.value)
	_music_value.text = "%d%%" % roundi(_music_slider.value)
	_sfx_value.text = "%d%%" % roundi(_sfx_slider.value)

func _apply_display_settings(_enabled: bool = false) -> void:
	_save_manager.apply_display_settings(_fullscreen_toggle.button_pressed, _vsync_toggle.button_pressed)
	_save_manager.save_display_settings(_fullscreen_toggle.button_pressed, _vsync_toggle.button_pressed)

func _play_menu_click() -> void:
	var audio: Variant = get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_menu_confirm()
