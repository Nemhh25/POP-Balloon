class_name MainHud
extends Control

@onready var _coins_label: Label = %CoinsLabel
@onready var _click_damage_label: Label = %ClickDamageLabel
@onready var _auto_dps_label: Label = %AutoDpsLabel
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _objective_label: Label = %ObjectiveLabel
@onready var _notification_label: Label = %NotificationLabel
@onready var _click_upgrade_button: Button = %ClickUpgradeButton
@onready var _needle_button: Button = %NeedleButton
@onready var _unlock_blue_button: Button = %UnlockBlueButton

var _session: GameSession

func bind(session: GameSession) -> void:
	_session = session
	_session.coins_changed.connect(_on_coins_changed)
	_session.click_damage_changed.connect(_on_click_damage_changed)
	_session.auto_dps_changed.connect(_on_auto_dps_changed)
	_session.balloon_health_changed.connect(_on_balloon_health_changed)
	_session.objective_changed.connect(_on_objective_changed)
	_session.notification_requested.connect(_on_notification_requested)
	_click_upgrade_button.pressed.connect(_session.request_click_upgrade)
	_needle_button.pressed.connect(_session.request_needle_upgrade)
	_unlock_blue_button.pressed.connect(_session.request_unlock_blue)
	_refresh_from_session()

func _refresh_from_session() -> void:
	_on_coins_changed(_session.get_coins())
	_on_click_damage_changed(_session.get_click_damage(), _session.get_next_click_upgrade_cost())
	_on_auto_dps_changed(_session.get_auto_dps(), _session.get_needle_level(), _session.get_next_needle_cost())

func _on_coins_changed(value: int) -> void:
	_coins_label.text = "Coins: %s" % _format_number(value)
	_refresh_button_states()

func _on_click_damage_changed(value: float, next_cost: int) -> void:
	_click_damage_label.text = "Click Damage: %s" % _format_number(value)
	_click_upgrade_button.text = "Upgrade Click Damage\n%s Coins" % _format_number(next_cost)
	_click_upgrade_button.disabled = next_cost == 0
	_refresh_button_states()

func _on_auto_dps_changed(value: float, needle_level: int, next_cost: int) -> void:
	_auto_dps_label.text = "Auto DPS: %s" % _format_number(value)
	_needle_button.text = "Needle Lv. %d\n%s Coins" % [needle_level, _format_number(next_cost)]
	_needle_button.disabled = next_cost == 0
	_refresh_button_states()

func _on_balloon_health_changed(current_health: float, max_health: float) -> void:
	_health_bar.max_value = max_health
	_health_bar.value = current_health
	_health_label.text = "HP: %s / %s" % [_format_number(ceili(current_health)), _format_number(ceili(max_health))]

func _on_objective_changed(text: String, can_unlock: bool) -> void:
	_objective_label.text = text
	_unlock_blue_button.visible = "Unlock Blue:" in text
	_unlock_blue_button.disabled = not can_unlock

func _on_notification_requested(text: String) -> void:
	_notification_label.text = text

func _refresh_button_states() -> void:
	if _session == null:
		return
	_click_upgrade_button.disabled = not _session.can_buy_click_damage()
	_needle_button.disabled = not _session.can_buy_needle()

func _format_number(value: float) -> String:
	return "%d" % roundi(value)
