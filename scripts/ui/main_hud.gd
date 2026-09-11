class_name MainHud
extends Control

signal main_menu_requested
signal quit_requested
signal pause_visibility_changed(is_visible: bool)

const NEEDLE_ID := &"needle"
const DART_ID := &"dart"
const DART_LAUNCHER_ID := &"dart_launcher"
const PRESSURE_GUN_ID := &"pressure_gun"
const POPPING_MACHINE_ID := &"balloon_popping_machine"
const POPBOT_ID := &"popbot"
const CANNON_ID := &"anti_balloon_cannon"
const GLOBAL_UPGRADES_ID := &"global_upgrades"

@onready var _coins_label: Label = %CoinsLabel
@onready var _diamonds_label: Label = %DiamondsLabel
@onready var _buff_label: Label = %BuffLabel
@onready var _click_damage_label: Label = %ClickDamageLabel
@onready var _auto_dps_label: Label = %AutoDpsLabel
@onready var _critical_label: Label = %CriticalLabel
@onready var _combo_label: Label = %ComboLabel
@onready var _tier_label: Label = %TierLabel
@onready var _objective_label: Label = %ObjectiveLabel
@onready var _objective_title: Label = $Margin/Layout/Body/Play/ObjectivePanel/Layout/Title
@onready var _objective_requirements: HBoxContainer = $Margin/Layout/Body/Play/ObjectivePanel/Layout/Requirements
@onready var _notification_label: Label = %NotificationLabel
@onready var _click_upgrade_button: Button = %ClickUpgradeButton
@onready var _critical_chance_button: Button = %CriticalChanceButton
@onready var _critical_damage_button: Button = %CriticalDamageButton
@onready var _coin_reward_button: Button = %CoinRewardButton
@onready var _diamond_reward_button: Button = %DiamondRewardButton
@onready var _diamond_event_frequency_button: Button = %DiamondEventFrequencyButton
@onready var _buff_frequency_button: Button = %BuffFrequencyButton
@onready var _needle_button: Button = %NeedleButton
@onready var _dart_button: Button = %DartButton
@onready var _dart_launcher_button: Button = %DartLauncherButton
@onready var _pressure_gun_button: Button = %PressureGunButton
@onready var _popping_machine_button: Button = %PoppingMachineButton
@onready var _popbot_button: Button = %PopBotButton
@onready var _cannon_button: Button = %CannonButton
@onready var _auto_dps_core_button: Button = %AutoDpsCoreButton
@onready var _coin_magnet_button: Button = %CoinMagnetButton
@onready var _click_core_button: Button = %ClickCoreButton
@onready var _critical_core_button: Button = %CriticalCoreButton
@onready var _unlock_balloon_button: Button = %UnlockBlueButton
@onready var _previous_balloon_button: Button = %PreviousBalloonButton
@onready var _next_unlocked_balloon_button: Button = %NextUnlockedBalloonButton
@onready var _victory_overlay: ColorRect = %VictoryOverlay
@onready var _victory_stats: Label = %Stats
@onready var _continue_endless_button: Button = %ContinueEndlessButton
@onready var _game_hud: MarginContainer = $Margin
@onready var _hold_click_toggle: CheckButton = %HoldClickToggle
@onready var _settings_button: Button = %SettingsButton
@onready var _statistics_button: Button = %StatisticsButton
@onready var _pause_button: Button = %PauseButton
@onready var _pause_overlay: ColorRect = %PauseOverlay

const Card = preload("res://scripts/ui/upgrade_card.gd")
const Numbers = preload("res://scripts/ui/number_format.gd")
const UPGRADE_ICON_SHEET: Texture2D = preload("res://assets/ui/sprites/upgrade_icons.png")
const CLICK_CORE_ICON: Texture2D = preload("res://assets/ui/sprites/click_core.png")
var _session: GameSession
var _cards: Dictionary = {}
var _render_pending := false
var _last_coins := -1
var _last_diamonds := -1
var _manual_damage_sequence_index := 0
var _auto_damage_sequence_index := 0
var _notification_tween: Tween
var _status_row: HFlowContainer
var _effects: Control
var _feedback_lanes: Dictionary = {}
var _combo_tween: Tween
var _displayed_stacks := 0
var _motion: Dictionary = {}
var _currency_pulse_at: Dictionary = {}
var _feedback_random := RandomNumberGenerator.new()
var _last_buff := ""
var _unlock_ready := false
var _visible_cards: Dictionary = {}
var _cards_initialized := false
var _audio_settings_panel: PanelContainer
var _statistics_panel: PanelContainer
var _statistics_text: Label
var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _fullscreen_toggle: CheckButton
var _vsync_toggle: CheckButton
var _volume_values: Dictionary = {}
var _global_buttons: Dictionary = {}
@onready var _tabs: TabContainer = %ShopTabs
@onready var _buy_one_button: Button = %BuyOneButton
@onready var _buy_ten_button: Button = %BuyTenButton
@onready var _buy_max_button: Button = %BuyMaxButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_effects = Control.new()
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_effects)
	move_child(_effects, _victory_overlay.get_index())
	_status_row = HFlowContainer.new()
	_status_row.alignment = FlowContainer.ALIGNMENT_CENTER
	var play := %Stage.get_parent()
	play.add_theme_constant_override("separation", 6)
	play.add_child(_status_row)
	play.move_child(_status_row, %Stage.get_index() + 1)
	_combo_label.reparent(_status_row)
	_buff_label.reparent(_status_row)
	for tab in _tabs.get_children():
		var list := tab.get_node("List")
		for button in list.get_children():
			var card := Card.new()
			list.add_child(card)
			card.attach(button)
			_cards[button] = card
	_setup_card_icons()
	_click_upgrade_button.show()
	_currency_badge(_coins_label, "res://assets/ui/coin.svg", Color("ffdc60"))
	_currency_badge(_diamonds_label, "res://assets/ui/diamond.svg", Color("d1baff"))
	for label in [_tier_label, _combo_label, _objective_label, %Title, $Margin/Layout/TopBar/Brand]:
		label.theme_type_variation = "ArcadeTitle"
	$Margin/Layout/TopBar/Brand.add_theme_color_override("font_color", Color("ffdc60"))
	_unlock_balloon_button.theme_type_variation = "ActionButton"
	_continue_endless_button.theme_type_variation = "ActionButton"
	_hold_click_toggle.tooltip_text = tr("Hold the mouse button on the balloon to keep clicking. Switch ON or OFF.")
	_hold_click_toggle.toggled.connect(_on_hold_visual)
	_on_hold_visual(false)
	_tabs.tab_changed.connect(_on_tab_visual)
	_critical_label.tooltip_text = tr("Critical hits multiply manual damage. Chance and multiplier come from your upgrades.")
	_combo_label.tooltip_text = tr("Consecutive clicks build Combo. Pausing resets it.")
	_buff_label.tooltip_text = tr("Temporary damage bonus. The countdown shows remaining seconds.")
	for button in [_unlock_balloon_button, _previous_balloon_button, _next_unlocked_balloon_button, _continue_endless_button, _hold_click_toggle]:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_settings_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_settings_button.pressed.connect(_toggle_audio_settings)
	_statistics_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_statistics_button.pressed.connect(_toggle_statistics)
	_pause_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_pause_button.pressed.connect(toggle_pause)
	%ResumeButton.pressed.connect(_resume_game)
	%PauseSettingsButton.pressed.connect(_open_pause_settings)
	%MainMenuButton.pressed.connect(_return_to_main_menu)
	%PauseQuitButton.pressed.connect(func() -> void: quit_requested.emit())
	for button: Button in [%ResumeButton, %PauseSettingsButton, %MainMenuButton, %PauseQuitButton]:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.focus_mode = Control.FOCUS_ALL
	_pause_overlay.hide()
	%PauseOverlay.get_node("Center/Panel/Layout/Title").text = tr("Paused")
	%ResumeButton.text = tr("Resume")
	%PauseSettingsButton.text = tr("Settings")
	%MainMenuButton.text = tr("Main Menu")
	%PauseQuitButton.text = tr("Quit")
	for pair in [[_buy_one_button, GameSession.BuyMode.ONE], [_buy_ten_button, GameSession.BuyMode.TEN], [_buy_max_button, GameSession.BuyMode.MAX]]:
		var buy_button := pair[0] as Button
		var buy_mode := int(pair[1])
		buy_button.toggle_mode = true
		buy_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		buy_button.pressed.connect(_on_buy_mode_pressed.bind(buy_mode))

func _on_buy_mode_pressed(mode: int) -> void:
	if _session != null:
		_session.set_buy_mode(mode)

func _currency_badge(label: Label, texture_path: String, color: Color) -> void:
	var parent := label.get_parent()
	var index := label.get_index()
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	parent.move_child(panel, index)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load(texture_path)
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	label.reparent(row)
	label.theme_type_variation = "ArcadeTitle"
	label.add_theme_color_override("font_color", color)
	label.visibility_changed.connect(func(): panel.visible = label.visible)

func _setup_card_icons() -> void:
	_set_card_icon(_click_upgrade_button, Vector2i(0, 0))
	_set_card_icon(_critical_chance_button, Vector2i(1, 0))
	_set_card_icon(_critical_damage_button, Vector2i(2, 0))
	_set_card_icon(_coin_reward_button, Vector2i(3, 0))
	_set_card_icon(_diamond_reward_button, Vector2i(0, 1))
	_set_card_icon(_diamond_event_frequency_button, Vector2i(0, 1))
	_set_card_icon(_buff_frequency_button, Vector2i(1, 1))
	_set_card_icon(_needle_button, Vector2i(2, 1))
	_set_card_icon(_dart_button, Vector2i(3, 1))
	_set_card_icon(_dart_launcher_button, Vector2i(0, 2))
	_set_card_icon(_pressure_gun_button, Vector2i(1, 2))
	_set_card_icon(_popping_machine_button, Vector2i(2, 2))
	_set_card_icon(_popbot_button, Vector2i(3, 2))
	_set_card_icon(_cannon_button, Vector2i(0, 3))
	_set_card_icon(_auto_dps_core_button, Vector2i(1, 3))
	_set_card_icon(_coin_magnet_button, Vector2i(2, 3))
	_set_card_texture(_click_core_button, CLICK_CORE_ICON)
	_set_card_icon(_critical_core_button, Vector2i(3, 3))

func _set_card_icon(button: Button, cell: Vector2i) -> void:
	var card: Card = _cards.get(button)
	if card == null:
		return
	var sheet_size := UPGRADE_ICON_SHEET.get_size()
	var cell_size := sheet_size / 4.0
	var icon := AtlasTexture.new()
	icon.atlas = UPGRADE_ICON_SHEET
	icon.region = Rect2(Vector2(cell) * cell_size, cell_size)
	icon.filter_clip = true
	card.set_icon(icon)

func _set_card_texture(button: Button, texture: Texture2D) -> void:
	var card: Card = _cards.get(button)
	if card != null:
		card.set_icon(texture)

func _bump(control: Control, amount: float = 1.04) -> void:
	if _motion.has(control): _motion[control].kill()
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * amount
	var tween := create_tween()
	_motion[control] = tween
	tween.tween_property(control, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_hold_visual(enabled: bool) -> void:
	_hold_click_toggle.text = tr("Hold to click") + (" · ON" if enabled else " · OFF")
	_hold_click_toggle.modulate = Color("73e4bd") if enabled else Color("acbbd3")
	_bump(_hold_click_toggle, 1.025)

func _on_tab_visual(index: int) -> void:
	_audio().play_tab()
	var page: Control = _tabs.get_child(index)
	_tabs.set_tab_title(index, page.name)
	if _motion.has(page): _motion[page].kill()
	page.modulate.a = 0.55
	var tween := create_tween()
	_motion[page] = tween
	tween.tween_property(page, "modulate:a", 1.0, 0.14)

func _audio() -> Variant:
	return get_node_or_null("/root/AudioManager")

func _currency_motion(label: Label, previous: int, value: int) -> void:
	if previous < 0 or previous == value: return
	var now := Time.get_ticks_msec()
	if now - int(_currency_pulse_at.get(label, -1000)) < 250: return
	_currency_pulse_at[label] = now
	_bump(label, 1.045 if value > previous else 0.975)

func _queue_cards() -> void:
	if _render_pending: return
	_render_pending = true
	_render_cards.call_deferred()

func bind(session: GameSession) -> void:
	_session = session
	_setup_global_cards()
	_session.purchase_completed.connect(_on_click_milestone)
	_session.balloon_health_changed.connect(_on_visual_damage)
	_session._balloon_controller.balloon_damaged.connect(_show_damage)
	_session._balloon_controller._container.child_entered_tree.connect(func(_node: Node): _on_visual_damage.call_deferred(0.0, 0.0))
	var buff_clock := Timer.new()
	buff_clock.wait_time = 1.0
	buff_clock.timeout.connect(func(): _on_buffs_changed(_session._buffs.get_active_text()))
	add_child(buff_clock)
	buff_clock.start()
	_session.coins_changed.connect(_on_coins_changed)
	_session.diamonds_changed.connect(_on_diamonds_changed)
	_session.buffs_changed.connect(_on_buffs_changed)
	_session.global_upgrades_changed.connect(_on_global_upgrades_changed)
	_session.active_upgrades_changed.connect(_refresh_active_upgrades)
	_session.click_damage_changed.connect(_on_click_damage_changed)
	_session.auto_dps_changed.connect(_on_auto_dps_changed)
	_session.equipment_presentation_changed.connect(_on_equipment_presentation_changed)
	_session.critical_presentation_changed.connect(_on_critical_presentation_changed)
	_session.combo_changed.connect(_on_combo_changed)
	_session.reveal_states_changed.connect(_on_reveal_states_changed)
	_session.content_revealed.connect(_on_content_revealed)
	_session.objective_changed.connect(_on_objective_changed)
	_session.current_balloon_changed.connect(_on_current_balloon_changed)
	_session.notification_requested.connect(_on_notification_requested)
	_session.victory_requested.connect(_on_victory_requested)
	_session.hold_click_option_changed.connect(func(enabled: bool) -> void: _hold_click_toggle.button_pressed = enabled)
	_session.buy_mode_changed.connect(_refresh_buy_mode)
	_session.audio_settings_changed.connect(_on_audio_settings_changed)
	_click_upgrade_button.pressed.connect(_session.request_click_upgrade)
	_critical_chance_button.pressed.connect(_session.request_critical_chance_upgrade)
	_critical_damage_button.pressed.connect(_session.request_critical_damage_upgrade)
	_coin_reward_button.pressed.connect(_session.request_coin_reward_upgrade)
	_diamond_reward_button.pressed.connect(_session.request_diamond_reward_upgrade)
	_diamond_event_frequency_button.pressed.connect(_session.request_diamond_event_frequency_upgrade)
	_needle_button.pressed.connect(_session.request_needle_upgrade)
	_dart_button.pressed.connect(_session.request_dart_upgrade)
	_dart_launcher_button.pressed.connect(_session.request_dart_launcher_upgrade)
	_pressure_gun_button.pressed.connect(_session.request_pressure_gun_upgrade)
	_popping_machine_button.pressed.connect(_session.request_popping_machine_upgrade)
	_popbot_button.pressed.connect(_session.request_popbot_upgrade)
	_cannon_button.pressed.connect(_session.request_cannon_upgrade)
	_auto_dps_core_button.pressed.connect(func() -> void: _session.request_global_upgrade(&"auto_dps_core"))
	_coin_magnet_button.pressed.connect(func() -> void: _session.request_global_upgrade(&"coin_magnet"))
	_click_core_button.pressed.connect(func() -> void: _session.request_global_upgrade(&"click_core"))
	_critical_core_button.pressed.connect(func() -> void: _session.request_global_upgrade(&"critical_core"))
	_unlock_balloon_button.pressed.connect(_session.request_unlock_next_balloon)
	_previous_balloon_button.pressed.connect(_session.request_previous_balloon)
	_next_unlocked_balloon_button.pressed.connect(_session.request_next_unlocked_balloon)
	_continue_endless_button.pressed.connect(_continue_into_endless)
	_hold_click_toggle.toggled.connect(_session.set_hold_click_enabled)
	_hold_click_toggle.button_pressed = _session.is_hold_click_enabled()
	_refresh_from_session()
	_create_audio_settings()

func _setup_global_cards() -> void:
	_global_buttons = {&"auto_dps_core": _auto_dps_core_button, &"coin_magnet": _coin_magnet_button, &"critical_core": _critical_core_button}
	_click_core_button.hide()
	var list := _cards[_auto_dps_core_button].get_parent() as VBoxContainer
	for data: GlobalUpgradeData in _session._catalog.global_upgrades:
		if data.legacy_only or _global_buttons.has(data.id):
			continue
		var button := Button.new()
		list.add_child(button)
		var card := Card.new()
		list.add_child(card)
		card.attach(button)
		_cards[button] = card
		_global_buttons[data.id] = button
		button.pressed.connect(_session.request_global_upgrade.bind(data.id))
		_set_card_icon(button, Vector2i(1, 1) if data.effect != GlobalUpgradeData.Effect.COMBO_POWER else Vector2i(3, 3))
	_cards[_diamond_event_frequency_button].reparent(list)
	var ordered_buttons: Array[Button] = [_auto_dps_core_button, _coin_magnet_button, _diamond_event_frequency_button]
	for id: StringName in [&"buff_duration", &"special_frequency", &"buff_power", &"combo_mastery", &"critical_core"]:
		ordered_buttons.append(_global_buttons[id])
	for index in ordered_buttons.size():
		list.move_child(_cards[ordered_buttons[index]], index)

func _on_click_milestone(_kind: StringName, id: StringName, _level: int, milestone: bool) -> void:
	if id == &"click_damage" and milestone:
		_cards[_click_upgrade_button].show_click_milestone()
	_create_statistics_panel()
	_refresh_buy_mode(_session.get_buy_mode())
	_on_audio_settings_changed(_session._state.master_volume, _session._state.music_volume, _session._state.sfx_volume)

func _create_audio_settings() -> void:
	if _audio_settings_panel != null: return
	_audio_settings_panel = PanelContainer.new()
	_audio_settings_panel.custom_minimum_size = Vector2(300, 0)
	_audio_settings_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_audio_settings_panel.position = Vector2(-324, 64)
	_audio_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_audio_settings_panel)
	var column := VBoxContainer.new()
	_audio_settings_panel.add_child(column)
	var title := Label.new()
	title.text = tr("SETTINGS")
	title.theme_type_variation = "ArcadeTitle"
	column.add_child(title)
	_master_slider = _add_volume_control(column, tr("Master Volume"))
	_music_slider = _add_volume_control(column, tr("Music Volume"))
	_sfx_slider = _add_volume_control(column, tr("SFX Volume"))
	_fullscreen_toggle = CheckButton.new()
	_fullscreen_toggle.text = tr("Fullscreen")
	column.add_child(_fullscreen_toggle)
	_vsync_toggle = CheckButton.new()
	_vsync_toggle.text = tr("VSync")
	column.add_child(_vsync_toggle)
	_hold_click_toggle.reparent(column)
	_hold_click_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var save_manager := get_node_or_null("/root/SaveManager") as PopSaveManager
	if save_manager != null:
		var display_settings := save_manager.load_display_settings()
		_fullscreen_toggle.set_pressed_no_signal(bool(display_settings["fullscreen"]))
		_vsync_toggle.set_pressed_no_signal(bool(display_settings["vsync"]))
		_fullscreen_toggle.toggled.connect(func(_enabled: bool) -> void: _apply_display_settings())
		_vsync_toggle.toggled.connect(func(_enabled: bool) -> void: _apply_display_settings())
	_audio_settings_panel.hide()

func _create_statistics_panel() -> void:
	if _statistics_panel != null:
		return
	_statistics_panel = PanelContainer.new()
	_statistics_panel.custom_minimum_size = Vector2(360, 0)
	_statistics_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_statistics_panel.position = Vector2(-384, 64)
	_statistics_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_statistics_panel)
	var column := VBoxContainer.new()
	_statistics_panel.add_child(column)
	var title := Label.new()
	title.text = tr("STATISTICS")
	title.theme_type_variation = "ArcadeTitle"
	column.add_child(title)
	_statistics_text = Label.new()
	_statistics_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_statistics_text)
	var close := Button.new()
	close.text = tr("Close")
	close.pressed.connect(_toggle_statistics)
	column.add_child(close)
	_statistics_panel.hide()

func _add_volume_control(parent: VBoxContainer, title: String) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 120
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = title
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 42
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	_volume_values[slider] = value_label
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%d%%" % roundi(value)
		_apply_audio_sliders()
	)
	return slider

func _toggle_audio_settings() -> void:
	if _audio_settings_panel == null: return
	_session.cancel_hold_click()
	if _statistics_panel != null: _statistics_panel.hide()
	_audio_settings_panel.visible = not _audio_settings_panel.visible
	_audio().play_tab()

func _toggle_statistics() -> void:
	if _statistics_panel == null: return
	_session.cancel_hold_click()
	if _audio_settings_panel != null: _audio_settings_panel.hide()
	_statistics_text.text = _session.get_statistics_text()
	_statistics_panel.visible = not _statistics_panel.visible
	_audio().play_tab()

func _refresh_buy_mode(mode: int) -> void:
	_buy_one_button.set_pressed_no_signal(mode == GameSession.BuyMode.ONE)
	_buy_ten_button.set_pressed_no_signal(mode == GameSession.BuyMode.TEN)
	_buy_max_button.set_pressed_no_signal(mode == GameSession.BuyMode.MAX)

func toggle_pause() -> void:
	if _victory_overlay.visible:
		return
	if _audio_settings_panel != null and _audio_settings_panel.visible:
		_audio_settings_panel.hide()
		return
	if _pause_overlay.visible:
		_resume_game()
		return
	_session.cancel_hold_click()
	_pause_overlay.show()
	pause_visibility_changed.emit(true)
	get_tree().paused = true
	%ResumeButton.grab_focus()
	_audio().play_tab()

func is_victory_visible() -> bool:
	return _victory_overlay.visible

func _resume_game() -> void:
	if _audio_settings_panel != null:
		_audio_settings_panel.hide()
	_pause_overlay.hide()
	get_tree().paused = false
	pause_visibility_changed.emit(false)
	_pause_button.grab_focus()

func _open_pause_settings() -> void:
	if _audio_settings_panel == null:
		return
	_session.cancel_hold_click()
	_audio_settings_panel.show()
	_audio().play_tab()

func _return_to_main_menu() -> void:
	_resume_game()
	main_menu_requested.emit()

func _apply_audio_sliders() -> void:
	if _session == null or _master_slider == null: return
	_session.set_audio_volumes(_master_slider.value / 100.0, _music_slider.value / 100.0, _sfx_slider.value / 100.0)

func _apply_display_settings() -> void:
	if _fullscreen_toggle == null or _vsync_toggle == null:
		return
	var save_manager := get_node_or_null("/root/SaveManager") as PopSaveManager
	if save_manager == null:
		return
	save_manager.apply_display_settings(_fullscreen_toggle.button_pressed, _vsync_toggle.button_pressed)
	save_manager.save_display_settings(_fullscreen_toggle.button_pressed, _vsync_toggle.button_pressed)

func _on_audio_settings_changed(master: float, music: float, sfx: float) -> void:
	if _master_slider == null: return
	_master_slider.set_value_no_signal(master * 100.0)
	_music_slider.set_value_no_signal(music * 100.0)
	_sfx_slider.set_value_no_signal(sfx * 100.0)
	for slider: HSlider in _volume_values:
		(_volume_values[slider] as Label).text = "%d%%" % roundi(slider.value)

func _refresh_from_session() -> void:
	_on_coins_changed(_session.get_coins())
	_on_diamonds_changed(_session.get_diamonds())
	_on_buffs_changed("")
	_on_click_damage_changed(_session.get_click_damage(), _session.get_click_damage_level(), _session.get_next_click_upgrade_cost())
	_on_auto_dps_changed(_session.get_auto_dps(), _session.get_needle_level(), _session.get_needle_dps(), _session.get_next_needle_dps(), _session.get_next_needle_cost())
	_on_equipment_presentation_changed()
	_on_critical_presentation_changed(_session.get_critical_chance_level(), _session.get_critical_chance(), _session.get_next_critical_chance_cost(), _session.get_critical_damage_level(), _session.get_critical_damage_multiplier(), _session.get_next_critical_damage_cost())
	_on_combo_changed(_session.get_combo_stacks(), _session.get_combo_multiplier())

func _on_coins_changed(value: int) -> void:
	_currency_motion(_coins_label, _last_coins, value)
	if _last_coins >= 0 and value > _last_coins:
		_float_feedback("+%s Coins" % _format_number_compact(value - _last_coins), Color("ffcf6a"), 22, 0.68)
	_last_coins = value
	_coins_label.text = _format_number_compact(value)
	_coins_label.tooltip_text = tr("Coins")
	_refresh_button_states()

func _on_diamonds_changed(value: int) -> void:
	_currency_motion(_diamonds_label, _last_diamonds, value)
	if _last_diamonds >= 0 and value > _last_diamonds:
		_float_feedback("+%s Diamonds!" % _format_number_compact(value - _last_diamonds), Color("a8abff"), 28, 0.5)
	_last_diamonds = value
	_diamonds_label.visible = true
	_diamonds_label.text = _format_number_compact(value)
	_diamonds_label.tooltip_text = tr("Diamonds")
	_refresh_active_upgrades()

func _on_buffs_changed(text: String) -> void:
	if text == _last_buff: return
	var starting := _last_buff.is_empty() and not text.is_empty()
	_last_buff = text
	if _motion.has(_buff_label): _motion[_buff_label].kill()
	if text.is_empty():
		var tween := create_tween()
		_motion[_buff_label] = tween
		tween.tween_property(_buff_label, "modulate:a", 0.0, 0.18)
		tween.tween_callback(_buff_label.hide)
	else:
		_buff_label.show()
		_buff_label.modulate = Color("ffcf6a")
		_buff_label.text = text.trim_prefix("BUFF: ")
		if starting: _bump(_buff_label)

func _on_click_damage_changed(value: float, level: int, next_cost: int) -> void:
	_click_damage_label.text = "Click: %s" % _format_damage(value)
	_click_upgrade_button.text = "Click Damage Lv. %d • Next: %s Coins" % [level, _cost_text(next_cost)]
	_click_upgrade_button.tooltip_text = tr("Adds 1 base damage per level. Every 25 levels adds 10% cumulative Click Damage; milestone bonuses add together.")
	_refresh_button_states()

func _on_auto_dps_changed(total_dps: float, _needle_level: int, _needle_dps: float, _next_needle_dps: float, _next_cost: int) -> void:
	_auto_dps_label.text = "DPS: %s" % _format_number_compact(total_dps)

func _on_equipment_presentation_changed() -> void:
	_refresh_equipment_button(_needle_button, NEEDLE_ID, "Needle", "Click Damage Lv. 2")
	_refresh_equipment_button(_dart_button, DART_ID, "Dart", "Blue Balloon + Click Damage Lv. 6")
	_refresh_equipment_button(_dart_launcher_button, DART_LAUNCHER_ID, "Dart Launcher", "Purple Balloon + Dart Lv. 10")
	_refresh_equipment_button(_pressure_gun_button, PRESSURE_GUN_ID, "Pressure Gun", "Dart Launcher Lv. 10 + Click Damage Lv. 16")
	_refresh_equipment_button(_popping_machine_button, POPPING_MACHINE_ID, "Popping Machine", "Dark + Pressure Gun Lv. 3 + 10 Dark pops")
	_refresh_equipment_button(_popbot_button, POPBOT_ID, "PopBot", "Popping Machine Lv. 10 + Click Lv. 22 + 60 Dark pops")
	_refresh_equipment_button(_cannon_button, CANNON_ID, "Anti-Balloon Cannon", "Rainbow + PopBot Lv. 10")
	_refresh_button_states()

func _on_global_upgrades_changed() -> void:
	_refresh_global_upgrades()
	_refresh_current_balloon_reward()

func _refresh_global_upgrades() -> void:
	var revealed := _session.get_reveal_state(GLOBAL_UPGRADES_ID) != RevealService.RevealState.HIDDEN
	_tabs.set_tab_hidden(2, not revealed)
	if not revealed:
		return
	for id: StringName in _global_buttons:
		_refresh_global_button(_global_buttons[id], id)

func _refresh_global_button(button: Button, id: StringName) -> void:
	var data := _session.get_global_upgrade_data(id)
	if data == null:
		return
	var cost := _session.get_global_upgrade_cost(id)
	button.visible = _session.is_global_upgrade_revealed(id)
	if not button.visible:
		return
	button.text = "%s Lv.%d • %s" % [data.display_name, _session.get_global_upgrade_level(id), "MAX" if cost == 0 else "%dD" % cost]
	button.disabled = cost == 0 or not _session.can_buy_global_upgrade(id)

func _refresh_equipment_button(button: Button, id: StringName, display_name: String, locked_requirement: String) -> void:
	var reveal_state := _session.get_reveal_state(id)
	button.visible = reveal_state != RevealService.RevealState.HIDDEN
	if not button.visible:
		return
	if not _session.is_equipment_available(id):
		button.text = "%s\nUnlock: %s" % [display_name, locked_requirement]
		button.disabled = true
		return
	var level := _session.get_equipment_level(id)
	var next_cost := _session.get_next_equipment_cost(id)
	button.text = "%s Lv.%d • %s DPS • %s" % [display_name, level, _format_number_compact(_session.get_equipment_dps(id)), "MAX" if next_cost == 0 else _format_number_compact(next_cost)]
	button.tooltip_text = _session.get_equipment_description(id)
	button.disabled = next_cost == 0 or not _session.can_buy_equipment(id)

func _on_critical_presentation_changed(chance_level: int, chance: float, chance_cost: int, damage_level: int, damage_multiplier: float, damage_cost: int) -> void:
	var chance_state := _session.get_reveal_state(&"critical_chance")
	var damage_state := _session.get_reveal_state(&"critical_damage")
	_critical_label.visible = chance_state != RevealService.RevealState.HIDDEN
	_critical_chance_button.visible = chance_state != RevealService.RevealState.HIDDEN
	_critical_damage_button.visible = damage_state != RevealService.RevealState.HIDDEN
	_critical_label.text = "Crit: %s %s" % [Numbers.percent(chance), Numbers.multiplier(damage_multiplier)]
	_critical_chance_button.text = "Critical Chance Lv. %d • +0.3%%\nNext: %s Coins" % [chance_level, _cost_text(chance_cost)]
	_critical_damage_button.text = "Critical Damage Lv. %d • ×%s\nNext: %s Coins" % [damage_level, _format_multiplier(damage_multiplier), _cost_text(damage_cost)]
	_critical_chance_button.tooltip_text = "Adds 0.3% Critical Chance per level, up to 35%."
	_critical_damage_button.tooltip_text = "Adds 0.3x critical damage per level, up to 2.5x."
	_refresh_active_upgrades()
	_refresh_button_states()

func _on_combo_changed(stacks: int, multiplier: float) -> void:
	_combo_label.visible = _session.get_reveal_state(&"combo") != RevealService.RevealState.HIDDEN
	_combo_label.text = "Combo: %d ×%s" % [stacks, _format_multiplier(multiplier)]
	if stacks >= _session._catalog.balance.combo_max_stacks: _combo_label.text += " · MAX"
	_combo_label.modulate = Color("73e4bd") if stacks > 1 else Color("acbbd3")
	if stacks != _displayed_stacks:
		if _combo_tween: _combo_tween.kill()
		var capped := stacks >= _session._catalog.balance.combo_max_stacks
		_combo_label.scale = Vector2.ONE * (1.09 if capped else 1.035 if stacks > _displayed_stacks else 0.97)
		_combo_tween = create_tween()
		_combo_tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.15)
	_displayed_stacks = stacks

func _on_reveal_states_changed() -> void:
	_on_equipment_presentation_changed()
	_on_critical_presentation_changed(_session.get_critical_chance_level(), _session.get_critical_chance(), _session.get_next_critical_chance_cost(), _session.get_critical_damage_level(), _session.get_critical_damage_multiplier(), _session.get_next_critical_damage_cost())
	_on_combo_changed(_session.get_combo_stacks(), _session.get_combo_multiplier())
	_refresh_global_upgrades()
	_refresh_active_upgrades()

func _refresh_active_upgrades() -> void:
	_queue_cards()
	_refresh_current_balloon_reward()
	for pair in [[_coin_reward_button, &"coin_reward"], [_diamond_reward_button, &"diamond_reward"], [_diamond_event_frequency_button, &"diamond_event_frequency"], [_buff_frequency_button, &"buff_frequency"]]:
		var button: Button = pair[0]
		var id: StringName = pair[1]
		button.visible = _session.is_active_upgrade_visible(id)
		button.text = _session.get_active_upgrade_text(id)
		button.tooltip_text = _session.get_active_upgrade_tooltip(id)
		button.disabled = id == &"buff_frequency" or not _session.can_buy_active_upgrade(id)

func _on_content_revealed(id: StringName) -> void:
	_on_reveal_states_changed()
	if id == &"combo": _bump(_combo_label)

func _on_objective_changed(text: String, can_unlock: bool, action_text: String) -> void:
	if _session._balloon_controller.is_boss_active():
		_show_boss_objective()
		return
	if _session.is_campaign_completed():
		_show_completed_navigation()
		return
	_objective_title.show()
	_objective_label.show()
	_objective_label.text = text
	_render_requirements(text)
	_unlock_balloon_button.visible = not action_text.is_empty()
	_unlock_balloon_button.text = action_text
	_unlock_balloon_button.disabled = not can_unlock
	if can_unlock and not _unlock_ready: _bump(_unlock_balloon_button, 1.025)
	_unlock_ready = can_unlock
	_previous_balloon_button.visible = _session.can_return_to_previous_balloon()
	_next_unlocked_balloon_button.visible = _session.can_advance_to_next_unlocked_balloon()

func _on_current_balloon_changed(text: String) -> void:
	_tier_label.text = text.trim_prefix("Current Balloon: ").to_upper()
	_refresh_current_balloon_reward()

func _refresh_current_balloon_reward() -> void:
	var balloon := _session._balloon_controller._current_balloon
	if not is_instance_valid(balloon) or balloon._data == null:
		return
	var reward := _session.get_balloon_coin_reward(balloon._data)
	if reward > 0:
		_tier_label.text = "%s · %s COINS" % [tr(balloon._data.display_name).to_upper(), Numbers.compact(reward)]

func _on_notification_requested(text: String) -> void:
	if text.begins_with("CRITICAL!"): return
	_notification_label.text = text
	if _notification_tween: _notification_tween.kill()
	_notification_label.modulate = Color("ffcf6a")
	_notification_tween = create_tween()
	_notification_tween.tween_interval(3.0)
	_notification_tween.tween_property(_notification_label, "modulate:a", 0.0, 0.35)

func _on_victory_requested() -> void:
	_game_hud.visible = false
	_effects.hide()
	_victory_overlay.visible = true
	_bump(_victory_stats, 1.025)
	var state := _session._state
	%Credits.text = PopCredits.get_text()
	_victory_stats.text = "Playtime: %s\n\nBalloons popped: %s   ·   Clicks: %s\nTotal damage: %s\nLargest critical: %s\nCoins earned: %s   ·   Diamonds: %s\nSpecial balloons: %s" % [_session._format_playtime(state.active_play_seconds), Numbers.compact(state.balloons_popped), Numbers.compact(state.total_clicks), Numbers.compact(state.total_damage), Numbers.compact(state.largest_critical), Numbers.compact(state.coins_earned), Numbers.compact(state.diamonds_earned), Numbers.compact(state.special_balloons_popped)]

func _continue_into_endless() -> void:
	_victory_overlay.visible = false
	_game_hud.visible = true
	_effects.show()
	_session.request_continue_endless()
	_audio().play_gameplay_music()

func _refresh_button_states() -> void:
	if _session == null:
		return
	_queue_cards()
	_click_upgrade_button.disabled = not _session.can_buy_click_damage()
	_critical_chance_button.disabled = not _session.can_buy_critical_chance()
	_critical_damage_button.disabled = not _session.can_buy_critical_damage()
	if _session.is_equipment_available(NEEDLE_ID):
		_needle_button.disabled = not _session.can_buy_equipment(NEEDLE_ID)
	if _session.is_equipment_available(DART_ID):
		_dart_button.disabled = not _session.can_buy_equipment(DART_ID)
	if _session.is_equipment_available(DART_LAUNCHER_ID):
		_dart_launcher_button.disabled = not _session.can_buy_equipment(DART_LAUNCHER_ID)
	if _session.is_equipment_available(PRESSURE_GUN_ID):
		_pressure_gun_button.disabled = not _session.can_buy_equipment(PRESSURE_GUN_ID)
	for id: StringName in [POPPING_MACHINE_ID, POPBOT_ID, CANNON_ID]:
		if _session.is_equipment_available(id):
			var button := {POPPING_MACHINE_ID: _popping_machine_button, POPBOT_ID: _popbot_button, CANNON_ID: _cannon_button}[id] as Button
			button.disabled = not _session.can_buy_equipment(id)
	_refresh_global_upgrades()

func _cost_text(cost: int) -> String:
	return "MAX" if cost == 0 else _format_number_compact(cost)

func _format_number(value: float) -> String:
	return "%d" % roundi(value)

func _format_number_compact(value: float) -> String:
	return Numbers.compact(value)

func _format_multiplier(value: float) -> String:
	return Numbers.decimal(value)

func _format_damage(value: float) -> String:
	return Numbers.compact(value)

# Presentation reads the existing services; no purchases, formulas or save writes here.
func _render_cards() -> void:
	_render_pending = false
	if _session == null: return
	var state := _session._state
	var balance := _session._balance
	var click_effect := "%s damage" % Numbers.compact(_session.get_click_damage())
	if _session.get_next_click_upgrade_cost() > 0:
		click_effect = "%s → %s damage" % [Numbers.compact(_session.get_click_damage()), Numbers.compact(balance.get_click_damage(state.click_damage_level + 1))]
	else:
		click_effect += " · MAX"
	_cards[_click_upgrade_button].present(tr("Click Damage") + "  ·  Lv.%d" % state.click_damage_level, click_effect, _session.get_click_milestone_text())
	_cards[_click_upgrade_button].set_click_progress(state.click_damage_level, _session._catalog.balance.click_milestone_interval)
	_purchase_text(_click_upgrade_button, _session.get_purchase_quote(&"click"))
	var chance_effect := Numbers.percent(_session.get_critical_chance())
	if _session.get_next_critical_chance_cost() > 0:
		chance_effect += " → %s chance" % Numbers.percent(balance.get_critical_chance(state.critical_chance_level + 1))
	else:
		chance_effect += " chance · MAX"
	_cards[_critical_chance_button].present(tr("Critical Chance") + "  ·  Lv.%d" % state.critical_chance_level, chance_effect)
	_purchase_text(_critical_chance_button, _session.get_purchase_quote(&"critical_chance"))
	var critical_effect := Numbers.multiplier(_session.get_critical_damage_multiplier())
	if _session.get_next_critical_damage_cost() > 0:
		critical_effect += " → %s critical damage" % Numbers.multiplier(balance.get_critical_damage_multiplier(state.critical_damage_level + 1))
	else:
		critical_effect += " critical damage · MAX"
	_cards[_critical_damage_button].present(tr("Critical Damage") + "  ·  Lv.%d" % state.critical_damage_level, critical_effect)
	_purchase_text(_critical_damage_button, _session.get_purchase_quote(&"critical_damage"))
	var equipment_buttons := {NEEDLE_ID: _needle_button, DART_ID: _dart_button, DART_LAUNCHER_ID: _dart_launcher_button, PRESSURE_GUN_ID: _pressure_gun_button, POPPING_MACHINE_ID: _popping_machine_button, POPBOT_ID: _popbot_button, CANNON_ID: _cannon_button}
	var equipment_visible := false
	for id: StringName in equipment_buttons:
		var button: Button = equipment_buttons[id]
		if not button.visible: continue
		equipment_visible = true
		var data := _session._catalog.find_equipment(id)
		var level := _session.get_equipment_level(id)
		var milestone := ""
		for i in mini(data.milestone_levels.size(), data.milestone_multipliers.size()):
			if data.milestone_levels[i] > level and data.milestone_levels[i] <= data.max_level:
				milestone = "Next milestone: Lv.%d · ×%s DPS (%d levels)" % [data.milestone_levels[i], _format_multiplier(data.milestone_multipliers[i]), data.milestone_levels[i] - level]
				break
		var equipment_effect := "%s DPS" % Numbers.compact(_session.get_equipment_dps(id))
		if _session.get_next_equipment_cost(id) > 0:
			equipment_effect += " → %s DPS" % Numbers.compact(_session.get_next_equipment_dps(id))
		else:
			equipment_effect += " · MAX"
		_cards[button].present(tr(data.display_name) + "  ·  Lv.%d" % level, equipment_effect, milestone)
		_cards[button].update_level(level, data.milestone_levels, data.milestone_multipliers)
		if _session.is_equipment_available(id): _purchase_text(button, _session.get_purchase_quote(&"equipment", id))
	_tabs.set_tab_hidden(1, not equipment_visible)
	for id: StringName in _global_buttons:
		var button: Button = _global_buttons[id]
		var data := _session.get_global_upgrade_data(id)
		var global_level := _session.get_global_upgrade_level(id)
		var global_effect: String
		if id == &"special_frequency":
			global_effect = "Every %d normal pops" % _session.get_buff_special_pop_interval(global_level)
			if _session.get_global_upgrade_cost(id) > 0:
				global_effect += " → Every %d pops" % _session.get_buff_special_pop_interval(global_level + 1)
			else:
				global_effect += " · MAX"
		else:
			global_effect = "+%s%%" % Numbers.decimal(global_level * data.bonus_per_level * 100.0)
			if _session.get_global_upgrade_cost(id) > 0:
				global_effect += " → +%s%%" % Numbers.decimal((global_level + 1) * data.bonus_per_level * 100.0)
			else:
				global_effect += " · MAX"
		_cards[button].present("◆ " + tr(data.display_name) + "  ·  Lv.%d/%d" % [global_level, data.max_level], global_effect, tr(data.description))
		_purchase_text(button, _session.get_purchase_quote(&"global", id), "Diamonds")
	for id: StringName in [&"coin_reward", &"diamond_reward", &"diamond_event_frequency", &"buff_frequency"]:
		var button: Button = {&"coin_reward": _coin_reward_button, &"diamond_reward": _diamond_reward_button, &"diamond_event_frequency": _diamond_event_frequency_button, &"buff_frequency": _buff_frequency_button}[id]
		var text := _session.get_active_upgrade_text(id)
		var parts := text.split(" • ")
		var active_effect := parts[1] if parts.size() > 1 else ""
		if id == &"coin_reward" and state.coin_reward_level < _session._catalog.balance.coin_reward_max_level:
			active_effect = "+%s%% → +%s%%" % [Numbers.decimal(state.coin_reward_level * _session._catalog.balance.coin_reward_bonus_per_level * 100.0), Numbers.decimal((state.coin_reward_level + 1) * _session._catalog.balance.coin_reward_bonus_per_level * 100.0)]
		elif id == &"diamond_reward" and state.diamond_reward_level < _session._catalog.balance.diamond_reward_max_level:
			active_effect = "+%s%% → +%s%% bonus Diamond" % [Numbers.decimal(state.diamond_reward_level * _session._catalog.balance.diamond_reward_bonus_chance_per_level * 100.0), Numbers.decimal((state.diamond_reward_level + 1) * _session._catalog.balance.diamond_reward_bonus_chance_per_level * 100.0)]
		elif id == &"diamond_event_frequency" and state.diamond_event_frequency_level < _session._catalog.balance.diamond_event_frequency_max_level:
			var current_interval := _session.get_diamond_event_interval_seconds()
			var next_reduction: float = (state.diamond_event_frequency_level + 1) * _session._catalog.balance.diamond_event_frequency_reduction_per_level
			var next_interval: float = _session._catalog.balance.diamond_event_base_interval_seconds * maxf(0.5, 1.0 - next_reduction)
			active_effect = "%ss → %ss between Diamond events" % [Numbers.decimal(current_interval), Numbers.decimal(next_interval)]
		_cards[button].present(parts[0], active_effect, _session.get_active_upgrade_tooltip(id))
		if id != &"buff_frequency":
			_purchase_text(button, _session.get_purchase_quote(&"active", id), "Coins" if id == &"coin_reward" else "Diamonds")
		else:
			_cards[button].progress.visible = true
			_cards[button].progress.max_value = _session._catalog.balance.buff_frequency_click_requirement
			_cards[button].progress.value = state.buff_frequency_clicks
			button.text = tr("MAX") if state.buff_frequency_level >= _session._catalog.balance.buff_frequency_max_level else tr("Next: +0.2% · Keep clicking")
	for button: Button in _cards:
		_cards[button].update_state()
		if _cards_initialized and button.visible and not _visible_cards.get(button, false):
			_cards[button].mark_new()
			var page: Control = _cards[button].get_parent().get_parent()
			if page.get_index() != _tabs.current_tab:
				_tabs.set_tab_title(page.get_index(), str(page.name) + " • NEW")
		_visible_cards[button] = button.visible
	_cards_initialized = true
	if _tabs.is_tab_hidden(_tabs.current_tab): _tabs.current_tab = 0

func _purchase_text(button: Button, quote: Dictionary, currency: String = "Coins") -> void:
	var next_cost := int(quote.get("next_cost", 0))
	var count := int(quote.get("count", 0))
	var total := int(quote.get("total", 0))
	if next_cost == 0:
		button.text = tr("MAX")
		return
	var shown_count := maxi(1, count)
	var shown_total := total if count > 0 else next_cost
	button.text = (tr("Buy") if count > 0 else tr("Need")) + " ×%d · %s%s %s" % [shown_count, "◆ " if currency == "Diamonds" else "", Numbers.compact(shown_total), tr(currency)]

func _render_requirements(fallback: String) -> void:
	var next := _session._progression.get_next_locked_balloon()
	var normal := next != null and not fallback.begins_with("Balloon King")
	%PopsProgress.get_parent().get_parent().visible = normal
	if not normal:
		%EquipmentRequirement.hide()
		%EquipmentRequirement.tooltip_text = ""
		%EquipmentRequirement.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	var previous := _session._progression.get_prerequisite_balloon(next)
	_objective_label.text = tr(next.display_name)
	_objective_label.modulate = next.display_color.lightened(0.45)
	var pops := _session._state.get_balloon_pops(previous.id)
	%PopsRequirement.text = "%s / %s %s pops" % [Numbers.compact(pops), Numbers.compact(next.unlock_pop_requirement), tr(previous.display_name)]
	%CoinsRequirement.text = "%s / %s Coins" % [Numbers.compact(_session.get_coins()), Numbers.compact(next.unlock_coin_requirement)]
	%PopsProgress.max_value = maxi(1, next.unlock_pop_requirement)
	%PopsProgress.value = pops
	%CoinsProgress.max_value = maxi(1, next.unlock_coin_requirement)
	%CoinsProgress.value = _session.get_coins()
	_requirement_state(%PopsRequirement, pops >= next.unlock_pop_requirement)
	_requirement_state(%CoinsRequirement, _session.get_coins() >= next.unlock_coin_requirement)
	if next.unlock_required_equipment_id.is_empty():
		%EquipmentRequirement.hide()
		%EquipmentRequirement.tooltip_text = ""
		%EquipmentRequirement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		var equipment_data := _session._catalog.find_equipment(next.unlock_required_equipment_id)
		%EquipmentRequirement.show()
		%EquipmentRequirement.text = "%s · Lv.%d / %d" % [tr(equipment_data.display_name), _session.get_equipment_level(next.unlock_required_equipment_id), next.unlock_required_equipment_level]
		var tooltip := _get_equipment_unlock_tooltip(next.unlock_required_equipment_id)
		# Updating this text every Auto DPS refresh closes Godot's native tooltip.
		# Preserve it while the exact requirement remains unchanged.
		if %EquipmentRequirement.tooltip_text != tooltip:
			%EquipmentRequirement.tooltip_text = tooltip
		# Labels normally ignore the pointer. This requirement must claim hover so
		# Godot can display its acquisition tooltip.
		%EquipmentRequirement.mouse_filter = Control.MOUSE_FILTER_STOP
		%EquipmentRequirement.mouse_default_cursor_shape = Control.CURSOR_HELP
		_requirement_state(%EquipmentRequirement, _session.get_equipment_level(next.unlock_required_equipment_id) >= next.unlock_required_equipment_level)

func _get_equipment_unlock_tooltip(equipment_id: StringName) -> String:
	var equipment_data := _session._catalog.find_equipment(equipment_id)
	if equipment_data == null:
		return ""
	var lines: Array[String] = ["To acquire %s:" % tr(equipment_data.display_name)]
	for rule: RevealRuleData in _session._catalog.reveal_rules:
		if rule.id != equipment_id:
			continue
		if rule.required_balloon_tier > 0:
			for balloon_data: BalloonData in _session._catalog.balloons:
				if balloon_data.category == BalloonData.Category.NORMAL and balloon_data.tier_index == rule.required_balloon_tier:
					lines.append("• Unlock %s" % tr(balloon_data.display_name))
					break
		if rule.required_click_damage_level > 1:
			lines.append("• Click Damage Lv.%d" % rule.required_click_damage_level)
		if not rule.required_equipment_id.is_empty():
			var prerequisite := _session._catalog.find_equipment(rule.required_equipment_id)
			if prerequisite != null:
				lines.append("• %s Lv.%d" % [tr(prerequisite.display_name), rule.required_equipment_level])
		if not rule.required_balloon_pop_id.is_empty():
			var pop_balloon := _session._catalog.find_balloon(rule.required_balloon_pop_id)
			if pop_balloon != null:
				lines.append("• %d %s pops" % [rule.required_balloon_pop_count, tr(pop_balloon.display_name)])
		if rule.required_diamond_count > 0:
			lines.append("• %d Diamonds" % rule.required_diamond_count)
		break
	lines.append("Then buy its level with Coins.")
	return "\n".join(lines)

func _requirement_state(label: Label, complete: bool) -> void:
	if complete: label.text += " ✓"
	label.modulate = Color("73e4bd") if complete else Color("acbbd3")

func _on_visual_damage(_health: float, _maximum: float) -> void:
	var balloon := _session._balloon_controller._current_balloon
	if is_instance_valid(balloon):
		_tier_label.text = tr(balloon._data.display_name).to_upper()
		_tier_label.modulate = balloon._data.display_color.lightened(0.45)
		_refresh_current_balloon_reward()
		if balloon._data.category == BalloonData.Category.BOSS:
			_tier_label.text = "♛ " + _tier_label.text + " · Phase %d" % maxi(1, _session._state.boss_phase)
			_show_boss_objective()

func _show_boss_objective() -> void:
	_objective_title.show()
	_objective_label.show()
	_objective_label.text = tr("Pop the Balloon King to complete the campaign!")
	%PopsProgress.get_parent().get_parent().hide()
	%EquipmentRequirement.hide()
	_unlock_balloon_button.hide()
	_previous_balloon_button.hide()
	_next_unlocked_balloon_button.hide()

func _show_completed_navigation() -> void:
	# Campaign completion has no next-tier objective. Keep only direct access to
	# already unlocked normal balloons once the victory overlay is dismissed.
	_objective_title.hide()
	_objective_label.hide()
	_objective_requirements.hide()
	%EquipmentRequirement.hide()
	_unlock_balloon_button.hide()
	_previous_balloon_button.visible = _session.can_return_to_previous_balloon()
	_next_unlocked_balloon_button.visible = _session.can_advance_to_next_unlocked_balloon()

func _float_feedback(text: String, color: Color, font_size: int, _height: float, sequence_index: int = -1, sequence_type: StringName = &"") -> void:
	if not is_node_ready() or _victory_overlay.visible: return
	var lane := "coins" if text.contains("Coins") else "diamonds" if text.contains("Diamonds") else "pop" if text == "POP!" else "critical" if text.begins_with("CRITICAL!") else "damage"
	var offset_lane := lane
	if sequence_index >= 0 and not sequence_type.is_empty():
		lane = "%s_%d" % [sequence_type, sequence_index]
		offset_lane = String(sequence_type)
	if _feedback_lanes.has(lane):
		var old: Dictionary = _feedback_lanes[lane]
		if is_instance_valid(old.label): old.label.queue_free()
		if old.tween: old.tween.kill()
		if old.cleanup: old.cleanup.kill()
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "ArcadeTitle"
	if lane == "diamonds": label.text = "◆ " + text
	if lane == "critical": label.text = text.replace("CRITICAL! ", "CRITICAL!\n")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	_effects.add_child(label)
	var stage: Control = %Stage
	var center := stage.global_position - global_position + stage.size * 0.5
	var offset: Vector2 = {"damage": Vector2(-145, -5), "manual": Vector2(-145, -5), "auto": Vector2(205, -5), "critical": Vector2(145, -5), "coins": Vector2(0, 78), "diamonds": Vector2(0, 120), "pop": Vector2(0, 0)}[offset_lane]
	if lane in ["damage", "critical"]:
		offset += Vector2(_feedback_random.randf_range(-14, 14), _feedback_random.randf_range(-8, 8))
	elif sequence_index >= 0:
		# Tight vertical columns keep rapid manual clicks and timed Auto DPS readable.
		offset += Vector2(0.0, sequence_index * (11.0 if sequence_type == &"manual" else 15.0))
	label.position = center + offset - label.get_minimum_size() * 0.5
	label.position.x = clampf(label.position.x, stage.global_position.x - global_position.x + 8, stage.global_position.x - global_position.x + stage.size.x - label.get_minimum_size().x - 8)
	label.pivot_offset = label.get_minimum_size() * 0.5
	var special := lane in ["critical", "diamonds", "pop"]
	label.scale = Vector2.ONE * (1.14 if special else 0.96)
	var tween := create_tween().set_parallel(true)
	var cleanup := create_tween()
	var feedback_lane := lane
	_feedback_lanes[feedback_lane] = {"label": label, "tween": tween, "cleanup": cleanup}
	var duration := 0.8 if lane == "diamonds" else 0.68 if sequence_index >= 0 else 0.55
	tween.tween_property(label, "scale", Vector2.ONE, 0.16)
	tween.tween_property(label, "position:y", label.position.y - (48 if lane == "critical" else 28), duration)
	tween.tween_property(label, "modulate:a", 0.0, duration - 0.18).set_delay(0.18)
	cleanup.tween_interval(duration)
	cleanup.tween_callback(func():
		if is_instance_valid(label): label.queue_free()
		var current: Dictionary = _feedback_lanes.get(feedback_lane, {})
		if current.get("label") == label:
			_feedback_lanes.erase(feedback_lane)
	)

func _show_damage(health: float, _maximum: float, attack: AttackResult) -> void:
	if attack.is_manual:
		var manual_index := _manual_damage_sequence_index % 8
		_manual_damage_sequence_index += 1
		_float_feedback("−%s" % Numbers.compact(attack.damage), Color("ffcf6a") if attack.was_critical else Color("edf4ff"), 24 if attack.was_critical else 20, 0.25, manual_index, &"manual")
	else:
		var auto_index := _auto_damage_sequence_index % 3
		_auto_damage_sequence_index += 1
		_float_feedback("AUTO  −%s" % Numbers.compact(attack.damage), Color("84e9ff"), 17, 0.25, auto_index, &"auto")
	if health <= 0:
		_float_feedback("POP!", Color("73e4bd"), 34, 0.4)
