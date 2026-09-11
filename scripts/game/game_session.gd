class_name GameSession
extends Node

signal coins_changed(value: int)
signal diamonds_changed(value: int)
signal buffs_changed(text: String)
signal global_upgrades_changed
signal active_upgrades_changed
signal click_damage_changed(value: float, level: int, next_cost: int)
signal auto_dps_changed(total_dps: float, needle_level: int, needle_dps: float, next_needle_dps: float, next_cost: int)
signal equipment_presentation_changed
signal critical_presentation_changed(chance_level: int, chance: float, chance_cost: int, damage_level: int, damage_multiplier: float, damage_cost: int)
signal combo_changed(stacks: int, multiplier: float)
signal reveal_states_changed
signal content_revealed(id: StringName)
signal balloon_health_changed(current_health: float, max_health: float)
signal objective_changed(text: String, can_unlock: bool, action_text: String)
signal current_balloon_changed(text: String)
signal notification_requested(text: String)
signal boss_phase_changed(phase: int, health: float, max_health: float)
signal victory_requested
signal hold_click_option_changed(enabled: bool)
signal manual_attack_performed
signal auto_attack_performed
signal purchase_completed(kind: StringName, id: StringName, level: int, milestone: bool)
signal balloon_tier_unlocked(id: StringName)
signal special_started_audio(id: StringName)
signal buff_started_audio
signal boss_started_audio
signal audio_settings_changed(master: float, music: float, sfx: float)
signal buy_mode_changed(mode: int)

const NEEDLE_ID := &"needle"
const DART_ID := &"dart"
const DART_LAUNCHER_ID := &"dart_launcher"
const PRESSURE_GUN_ID := &"pressure_gun"
const POPPING_MACHINE_ID := &"balloon_popping_machine"
const POPBOT_ID := &"popbot"
const CANNON_ID := &"anti_balloon_cannon"
const GLOBAL_UPGRADES_ID := &"global_upgrades"
const CLICK_DAMAGE_ID := &"click_damage"
const CRITICAL_CHANCE_ID := &"critical_chance"
const CRITICAL_DAMAGE_ID := &"critical_damage"
const COMBO_ID := &"combo"
const AUTOSAVE_INTERVAL_SECONDS := 60.0
const Numbers = preload("res://scripts/ui/number_format.gd")

enum BuyMode { ONE, TEN, MAX }

var _catalog: ContentCatalogData
var _state: GameState
var _balance: BalanceService
var _economy: EconomyService
var _upgrades: UpgradeService
var _equipment: EquipmentService
var _progression: ProgressionService
var _combat: CombatResolver
var _statistics: StatisticsService
var _reveal_service: RevealService
var _globals: GlobalUpgradeService
var _buffs: BuffService
var _special_scheduler: SpecialBalloonScheduler
var _balloon_controller: BalloonController
var _auto_damage_timer: Timer
var _autosave_timer: Timer
var _playtime_timer: Timer
var _combo_timer: Timer
var _save_manager: PopSaveManager
var _save_dirty := false
var _combo_stacks := 0
var _hold_click_enabled := false
var _hold_click_timer: Timer
var _hold_mouse_down := false
var _hold_pointer_position := Vector2.ZERO
var _buy_mode: BuyMode = BuyMode.ONE

func initialize(catalog: ContentCatalogData, balloon_scene: PackedScene, balloon_container: Control) -> void:
	assert(catalog != null and catalog.balance != null, "ContentCatalogData and GameBalanceData are required.")
	_catalog = catalog
	if not _validate_catalog():
		return
	_save_manager = get_node_or_null("/root/SaveManager") as PopSaveManager
	assert(_save_manager != null, "SaveManager autoload is required.")
	_state = _save_manager.load_game_state(_catalog)
	_balance = BalanceService.new(_catalog.balance)
	_economy = EconomyService.new(_state)
	_upgrades = UpgradeService.new(_state, _balance, _economy)
	_equipment = EquipmentService.new(_state, _catalog, _balance, _economy)
	_progression = ProgressionService.new(_state, _catalog, _economy)
	_combat = CombatResolver.new(_balance)
	_statistics = StatisticsService.new(_state)
	_reveal_service = RevealService.new(_state, _catalog)
	_reveal_service.initialize()
	_globals = GlobalUpgradeService.new(_state, _catalog, _economy)
	_buffs = BuffService.new()
	add_child(_buffs)

	_economy.coins_changed.connect(_on_coins_changed)
	_economy.diamonds_changed.connect(_on_diamonds_changed)
	_upgrades.click_damage_upgraded.connect(_on_click_damage_upgraded)
	_upgrades.critical_chance_upgraded.connect(_on_critical_chance_upgraded)
	_upgrades.critical_damage_upgraded.connect(_on_critical_damage_upgraded)
	_equipment.equipment_changed.connect(_on_equipment_changed)
	_globals.global_upgrade_changed.connect(_on_global_upgrade_changed)
	_buffs.buffs_changed.connect(func(text: String) -> void: buffs_changed.emit(text))
	_progression.objective_changed.connect(_on_objective_changed)
	_progression.tier_unlocked.connect(_on_tier_unlocked)

	_balloon_controller = BalloonController.new()
	add_child(_balloon_controller)
	_balloon_controller.setup(_catalog, _state, _balance, balloon_scene, balloon_container)
	_balloon_controller.balloon_clicked.connect(handle_balloon_click)
	_balloon_controller.balloon_hold_started.connect(_on_balloon_hold_started)
	_balloon_controller.balloon_hold_ended.connect(_on_balloon_hold_ended)
	_balloon_controller.balloon_damaged.connect(_on_balloon_damaged)
	_balloon_controller.balloon_popped.connect(_on_balloon_popped)
	_balloon_controller.special_balloon_popped.connect(_on_special_balloon_popped)
	_balloon_controller.boss_balloon_popped.connect(_on_boss_popped)
	_balloon_controller.spawn_current_normal()
	_hold_click_timer = Timer.new()
	_hold_click_timer.wait_time = 0.12
	_hold_click_enabled = _state.hold_click_enabled
	_hold_click_timer.timeout.connect(_on_hold_click_tick)
	add_child(_hold_click_timer)

	_special_scheduler = SpecialBalloonScheduler.new()
	add_child(_special_scheduler)
	_special_scheduler.setup(_catalog, _reveal_service, _state)
	_special_scheduler.special_started.connect(_on_special_started)
	_special_scheduler.special_expired.connect(_on_special_expired)

	_auto_damage_timer = Timer.new()
	_auto_damage_timer.wait_time = _balance.get_auto_damage_tick_interval()
	_auto_damage_timer.timeout.connect(_on_auto_damage_tick)
	add_child(_auto_damage_timer)
	_auto_damage_timer.start()

	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL_SECONDS
	_autosave_timer.timeout.connect(_on_autosave_timeout)
	add_child(_autosave_timer)
	_autosave_timer.start()

	_playtime_timer = Timer.new()
	_playtime_timer.wait_time = 1.0
	_playtime_timer.timeout.connect(_on_playtime_tick)
	add_child(_playtime_timer)
	_playtime_timer.start()

	_combo_timer = Timer.new()
	_combo_timer.one_shot = true
	_combo_timer.wait_time = _balance.get_combo_timeout_seconds()
	_combo_timer.timeout.connect(_on_combo_timeout)
	add_child(_combo_timer)

	_emit_full_state()
	_save_dirty = not _save_manager.requires_recovery()
	if _save_dirty:
		_save_now()

func handle_balloon_click() -> void:
	_statistics.record_click()
	if _state.buff_frequency_unlocked and _state.buff_frequency_level < _catalog.balance.buff_frequency_max_level:
		_state.buff_frequency_clicks += 1
		if _state.buff_frequency_clicks >= _catalog.balance.buff_frequency_click_requirement:
			_state.buff_frequency_clicks = 0
			_state.buff_frequency_level += 1
			notification_requested.emit("Buff Frequency +%.1f%%!" % (_catalog.balance.buff_frequency_bonus_per_level * 100.0))
			_save_now()
		active_upgrades_changed.emit()
	if _reveal_service.is_revealed(COMBO_ID):
		_combo_stacks = mini(_combo_stacks + 1, _balance.get_combo_max_stacks())
		_combo_timer.start()
		combo_changed.emit(_combo_stacks, get_combo_multiplier())
	var attack := _combat.calculate_manual_attack(_state, get_combo_multiplier() * _buffs.get_multiplier(BuffService.FRENZY_ID), _globals.get_effect_multiplier(GlobalUpgradeData.Effect.CLICK_DAMAGE), _globals.get_effect_multiplier(GlobalUpgradeData.Effect.CRITICAL_DAMAGE))
	_balloon_controller.damage_current_balloon(attack)
	if _balloon_controller.get_current_health() > 0.0:
		manual_attack_performed.emit()

func request_click_upgrade() -> void:
	if _buy_levels(Callable(_upgrades, "try_buy_click_damage")) > 0:
		_save_now()
	else:
		notification_requested.emit("Not enough Coins for Click Damage.")

func set_hold_click_enabled(enabled: bool) -> void:
	_hold_click_enabled = enabled
	_state.hold_click_enabled = enabled
	if not enabled:
		cancel_hold_click()
	hold_click_option_changed.emit(enabled)
	_save_manager.save_hold_click_setting(enabled)
	_save_now()

func set_buy_mode(mode: int) -> void:
	_buy_mode = clampi(mode, BuyMode.ONE, BuyMode.MAX)
	buy_mode_changed.emit(_buy_mode)
	_emit_purchase_state()

func get_buy_mode() -> BuyMode:
	return _buy_mode

# Preview the exact batch the active buy mode can afford without changing state.
# This mirrors the level-by-level purchase loop, so rising costs and caps stay honest.
func get_purchase_quote(kind: StringName, id: StringName = &"") -> Dictionary:
	var start_level := 0
	var max_level := 0 # Zero means uncapped.
	var funds := _state.coins
	match kind:
		&"click":
			start_level = _state.click_damage_level
			max_level = _balance.get_click_upgrade_max_level()
		&"critical_chance":
			start_level = _state.critical_chance_level
			max_level = _balance.get_critical_chance_max_level()
		&"critical_damage":
			start_level = _state.critical_damage_level
			max_level = _balance.get_critical_damage_max_level()
		&"equipment":
			var equipment_data := _catalog.find_equipment(id)
			if equipment_data == null:
				return {"count": 0, "total": 0, "next_cost": 0}
			start_level = _state.get_equipment_level(id)
			max_level = equipment_data.max_level
		&"global":
			var global_data := _catalog.find_global_upgrade(id)
			if global_data == null:
				return {"count": 0, "total": 0, "next_cost": 0}
			start_level = _state.get_global_upgrade_level(id)
			max_level = global_data.max_level
			funds = _state.diamonds
		&"active":
			start_level = _get_active_upgrade_level(id)
			max_level = _get_active_upgrade_max_level(id)
			funds = _state.coins if id == &"coin_reward" else _state.diamonds
		_:
			return {"count": 0, "total": 0, "next_cost": 0}
	if max_level > 0 and start_level >= max_level:
		return {"count": 0, "total": 0, "next_cost": 0}
	var next_cost := _get_purchase_cost_at_level(kind, id, start_level)
	if next_cost <= 0 or (kind == &"critical_damage" and _state.critical_chance_level <= 0):
		return {"count": 0, "total": 0, "next_cost": next_cost}
	var limit := _purchase_limit()
	var count := 0
	var total := 0
	while count < limit and (max_level <= 0 or start_level + count < max_level):
		var cost := _get_purchase_cost_at_level(kind, id, start_level + count)
		if cost <= 0 or total + cost > funds:
			break
		total += cost
		count += 1
	return {"count": count, "total": total, "next_cost": next_cost}

func _get_purchase_cost_at_level(kind: StringName, id: StringName, level: int) -> int:
	match kind:
		&"click": return _balance.get_click_upgrade_cost(level)
		&"critical_chance": return _balance.get_critical_chance_upgrade_cost(level)
		&"critical_damage": return _balance.get_critical_damage_upgrade_cost(level)
		&"equipment":
			var equipment_data := _catalog.find_equipment(id)
			return _balance.get_equipment_level_cost(equipment_data, level) if equipment_data != null else 0
		&"global":
			var global_data := _catalog.find_global_upgrade(id)
			return global_data.cost_at_level(level) if global_data != null else 0
		&"active": return _get_active_upgrade_cost_at_level(id, level)
	return 0

func _get_active_upgrade_level(id: StringName) -> int:
	match id:
		&"coin_reward": return _state.coin_reward_level
		&"diamond_reward": return _state.diamond_reward_level
		&"diamond_event_frequency": return _state.diamond_event_frequency_level
	return 0

func _get_active_upgrade_max_level(id: StringName) -> int:
	match id:
		&"coin_reward": return _catalog.balance.coin_reward_max_level
		&"diamond_reward": return _catalog.balance.diamond_reward_max_level
		&"diamond_event_frequency": return _catalog.balance.diamond_event_frequency_max_level
	return 0

func set_audio_volumes(master: float, music: float, sfx: float) -> void:
	_state.master_volume = clampf(master, 0.0, 1.0)
	_state.music_volume = clampf(music, 0.0, 1.0)
	_state.sfx_volume = clampf(sfx, 0.0, 1.0)
	audio_settings_changed.emit(_state.master_volume, _state.music_volume, _state.sfx_volume)
	_save_manager.save_audio_settings(_state.master_volume, _state.music_volume, _state.sfx_volume)
	_save_now()

func save_progress() -> void:
	_save_now()

func is_hold_click_enabled() -> bool:
	return _hold_click_enabled

func cancel_hold_click() -> void:
	_hold_mouse_down = false
	if _hold_click_timer != null:
		_hold_click_timer.stop()

func _on_balloon_hold_started() -> void:
	if _hold_click_enabled:
		_hold_mouse_down = true
		_hold_pointer_position = get_viewport().get_mouse_position()
		_hold_click_timer.start()

func _on_balloon_hold_ended() -> void:
	cancel_hold_click()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			cancel_hold_click()
		elif _hold_click_enabled:
			_hold_pointer_position = event.position
	elif event is InputEventMouseMotion and _hold_mouse_down:
		_hold_pointer_position = event.position

func _on_hold_click_tick() -> void:
	# Hold remains latched through a Balloon pop/respawn and while the pointer is
	# away from the target. Damage itself is still strictly hit-tested below.
	# Release, focus loss, pause, settings and scene changes cancel it elsewhere.
	if not _hold_click_enabled or not _hold_mouse_down:
		cancel_hold_click()
		return
	if _is_hold_target_valid():
		handle_balloon_click()

func _is_hold_target_valid() -> bool:
	var balloon := _balloon_controller._current_balloon
	return is_instance_valid(balloon) and balloon.get_current_health() > 0.0 and balloon._is_pointer_over_body(_hold_pointer_position)

func _buy_levels(purchase: Callable) -> int:
	var purchased := 0
	var limit := 1 if _buy_mode == BuyMode.ONE else 10 if _buy_mode == BuyMode.TEN else 2147483647
	while purchased < limit and bool(purchase.call()):
		purchased += 1
	return purchased

func request_needle_upgrade() -> void:
	request_equipment_upgrade(NEEDLE_ID)

func request_dart_upgrade() -> void:
	request_equipment_upgrade(DART_ID)

func request_dart_launcher_upgrade() -> void:
	request_equipment_upgrade(DART_LAUNCHER_ID)

func request_pressure_gun_upgrade() -> void:
	request_equipment_upgrade(PRESSURE_GUN_ID)

func request_popping_machine_upgrade() -> void:
	request_equipment_upgrade(POPPING_MACHINE_ID)

func request_popbot_upgrade() -> void:
	request_equipment_upgrade(POPBOT_ID)

func request_cannon_upgrade() -> void:
	request_equipment_upgrade(CANNON_ID)

func request_global_upgrade(id: StringName) -> void:
	if is_global_upgrade_revealed(id) and _buy_levels(Callable(_globals, "try_buy").bind(id)) > 0:
		_save_now()
	else:
		notification_requested.emit("Not enough Diamonds for that Global Upgrade.")

func request_equipment_upgrade(id: StringName) -> void:
	if _reveal_service.is_revealed(id) and _buy_levels(Callable(_equipment, "try_buy").bind(id)) > 0:
		_save_now()
	else:
		notification_requested.emit("Meet the unlock requirements or earn more Coins.")

func request_critical_chance_upgrade() -> void:
	if _reveal_service.is_revealed(CRITICAL_CHANCE_ID) and _buy_levels(Callable(_upgrades, "try_buy_critical_chance")) > 0:
		_save_now()
	else:
		notification_requested.emit("Not enough Coins for Critical Chance.")

func request_critical_damage_upgrade() -> void:
	if _reveal_service.is_revealed(CRITICAL_DAMAGE_ID) and _buy_levels(Callable(_upgrades, "try_buy_critical_damage")) > 0:
		_save_now()
	else:
		notification_requested.emit("Unlock Critical Chance and earn more Coins first.")

func request_coin_reward_upgrade() -> void:
	var purchased := 0
	while purchased < _purchase_limit() and _try_buy_active_upgrade(&"coin_reward"):
		purchased += 1
	if purchased > 0:
		_save_now()
		_emit_purchase_state()
		active_upgrades_changed.emit()
		purchase_completed.emit(&"upgrade", &"coin_reward", _state.coin_reward_level, false)

func request_diamond_reward_upgrade() -> void:
	var purchased := 0
	while purchased < _purchase_limit() and _try_buy_active_upgrade(&"diamond_reward"):
		purchased += 1
	if purchased > 0:
		_save_now()
		_emit_purchase_state()
		active_upgrades_changed.emit()
		purchase_completed.emit(&"upgrade", &"diamond_reward", _state.diamond_reward_level, false)

func request_diamond_event_frequency_upgrade() -> void:
	var purchased := 0
	while purchased < _purchase_limit() and _try_buy_active_upgrade(&"diamond_event_frequency"):
		purchased += 1
	if purchased > 0:
		_special_scheduler.refresh_diamond_event_frequency()
		_save_now()
		_emit_purchase_state()
		active_upgrades_changed.emit()
		purchase_completed.emit(&"upgrade", &"diamond_event_frequency", _state.diamond_event_frequency_level, false)

func _try_buy_active_upgrade(id: StringName) -> bool:
	var cost := get_active_upgrade_cost(id)
	if not is_active_upgrade_visible(id) or cost <= 0:
		return false
	if id == &"coin_reward":
		if not _economy.try_spend_coins(cost): return false
		_state.coin_reward_level += 1
	elif id == &"diamond_reward":
		if not _economy.try_spend_diamonds(cost): return false
		_state.diamond_reward_level += 1
	elif id == &"diamond_event_frequency":
		if not _economy.try_spend_diamonds(cost): return false
		_state.diamond_event_frequency_level += 1
	else:
		return false
	return true

func _purchase_limit() -> int:
	return 1 if _buy_mode == BuyMode.ONE else 10 if _buy_mode == BuyMode.TEN else 2147483647

func get_active_upgrade_text(id: StringName) -> String:
	match id:
		&"coin_reward": return "Coin Reward Lv.%d/%d • +%s%% • %s" % [_state.coin_reward_level, _catalog.balance.coin_reward_max_level, Numbers.decimal(_state.coin_reward_level * _catalog.balance.coin_reward_bonus_per_level * 100.0), _active_upgrade_cost_text(id)]
		&"diamond_reward": return "Diamond Reward Lv.%d/%d • +%s%% bonus Diamond • %s" % [_state.diamond_reward_level, _catalog.balance.diamond_reward_max_level, Numbers.decimal(_get_diamond_reward_bonus_chance() * 100.0), _active_upgrade_cost_text(id)]
		&"diamond_event_frequency": return "Diamond Event Frequency Lv.%d/%d • every %ss • %s" % [_state.diamond_event_frequency_level, _catalog.balance.diamond_event_frequency_max_level, Numbers.decimal(get_diamond_event_interval_seconds()), _active_upgrade_cost_text(id)]
		&"buff_frequency": return "Buff Frequency Lv.%d/%d • +%s%%\nClicks: %d / %d%s" % [_state.buff_frequency_level, _catalog.balance.buff_frequency_max_level, Numbers.decimal(_state.buff_frequency_level * _catalog.balance.buff_frequency_bonus_per_level * 100.0), _state.buff_frequency_clicks, _catalog.balance.buff_frequency_click_requirement, " • MAX" if _state.buff_frequency_level >= _catalog.balance.buff_frequency_max_level else ""]
	return ""

func get_active_upgrade_tooltip(id: StringName) -> String:
	match id:
		&"coin_reward": return "+5% Coins from normal balloons per level. Costs scale with the highest unlocked tier to keep payback meaningful."
		&"diamond_reward": return "+15% chance per level for one extra Diamond when a Crystal Balloon event grants Diamonds."
		&"diamond_event_frequency": return "Reduces only the time between Crystal Balloon Diamond events. It does not affect Coin or buff events."
		&"buff_frequency": return "Only valid manual balloon clicks count. Every 500 clicks grants +0.2% buff frequency, up to +5%."
	return ""

func get_active_upgrade_cost(id: StringName) -> int:
	return _get_active_upgrade_cost_at_level(id, _get_active_upgrade_level(id))

func _get_active_upgrade_cost_at_level(id: StringName, level: int) -> int:
	match id:
		&"coin_reward":
			if level >= _catalog.balance.coin_reward_max_level:
				return 0
			var highest := _get_highest_unlocked_normal_balloon()
			if highest == null:
				return 0
			return maxi(_catalog.balance.coin_reward_minimum_cost, roundi(highest.coin_reward * _catalog.balance.coin_reward_cost_reward_multiplier * pow(_catalog.balance.coin_reward_cost_growth, level)))
		&"diamond_reward":
			if level >= _catalog.balance.diamond_reward_max_level:
				return 0
			return _catalog.balance.diamond_reward_base_cost * (level + 1)
		&"diamond_event_frequency":
			if level >= _catalog.balance.diamond_event_frequency_max_level:
				return 0
			var costs := _catalog.balance.diamond_event_frequency_costs
			return costs[level] if level < costs.size() else 0
	return 0

func can_buy_active_upgrade(id: StringName) -> bool:
	var cost := get_active_upgrade_cost(id)
	if cost <= 0:
		return false
	return _state.coins >= cost if id == &"coin_reward" else _state.diamonds >= cost if id in [&"diamond_reward", &"diamond_event_frequency"] else false

func _active_upgrade_cost_text(id: StringName) -> String:
	var cost := get_active_upgrade_cost(id)
	if cost == 0:
		return "MAX"
	return "%s Coins" % Numbers.compact(cost) if id == &"coin_reward" else "%s Diamonds" % Numbers.compact(cost)

func _get_diamond_reward_bonus_chance() -> float:
	return minf(1.0, _state.diamond_reward_level * _catalog.balance.diamond_reward_bonus_chance_per_level)

func get_diamond_event_interval_seconds() -> float:
	var reduction := _state.diamond_event_frequency_level * _catalog.balance.diamond_event_frequency_reduction_per_level
	return _catalog.balance.diamond_event_base_interval_seconds * maxf(0.5, 1.0 - reduction)

func _get_highest_unlocked_normal_balloon() -> BalloonData:
	var highest: BalloonData = null
	for balloon_data: BalloonData in _catalog.balloons:
		if balloon_data.category == BalloonData.Category.NORMAL and _state.is_balloon_unlocked(balloon_data.id) and (highest == null or balloon_data.tier_index > highest.tier_index):
			highest = balloon_data
	return highest

func is_active_upgrade_visible(id: StringName) -> bool:
	if id == &"coin_reward": return _state.is_balloon_unlocked(&"purple_balloon")
	if id == &"diamond_reward": return _state.crystal_balloons_popped > 0
	if id == &"diamond_event_frequency": return _state.crystal_balloons_popped > 0 or _state.diamonds_earned > 0
	if id == &"buff_frequency": return _state.buff_frequency_unlocked
	return false

func request_unlock_next_balloon() -> void:
	if is_ready_for_balloon_king() and not _state.boss_unlocked and not _state.campaign_completed:
		_start_balloon_king()
		return
	if _progression.try_unlock_next_balloon():
		_save_now()
	else:
		notification_requested.emit("The next Balloon requirements are not met yet.")

func request_previous_balloon() -> void:
	if _balloon_controller.is_boss_active():
		return
	var current := _catalog.find_balloon(_state.current_normal_balloon_id)
	if current == null:
		return
	var previous: BalloonData = null
	for balloon_data: BalloonData in _catalog.balloons:
		if balloon_data.category == BalloonData.Category.NORMAL and _state.is_balloon_unlocked(balloon_data.id) and balloon_data.tier_index < current.tier_index and (previous == null or balloon_data.tier_index > previous.tier_index):
			previous = balloon_data
	if previous == null:
		return
	_balloon_controller.set_current_normal_balloon(previous.id)
	current_balloon_changed.emit(_get_current_balloon_text())
	_progression.emit_objective()
	notification_requested.emit("Returned to %s." % previous.display_name)
	_save_now()

func can_return_to_previous_balloon() -> bool:
	var current := _catalog.find_balloon(_state.current_normal_balloon_id)
	return current != null and current.tier_index > 1 and not _balloon_controller.is_boss_active()

func request_next_unlocked_balloon() -> void:
	if _balloon_controller.is_boss_active():
		return
	var current := _catalog.find_balloon(_state.current_normal_balloon_id)
	if current == null:
		return
	var next: BalloonData = null
	for balloon_data: BalloonData in _catalog.balloons:
		if balloon_data.category == BalloonData.Category.NORMAL and _state.is_balloon_unlocked(balloon_data.id) and balloon_data.tier_index > current.tier_index and (next == null or balloon_data.tier_index < next.tier_index):
			next = balloon_data
	if next == null:
		return
	_balloon_controller.set_current_normal_balloon(next.id)
	current_balloon_changed.emit(_get_current_balloon_text())
	_progression.emit_objective()
	notification_requested.emit("Advanced to %s." % next.display_name)
	_save_now()

func can_advance_to_next_unlocked_balloon() -> bool:
	var current := _catalog.find_balloon(_state.current_normal_balloon_id)
	if current == null or _balloon_controller.is_boss_active():
		return false
	for balloon_data: BalloonData in _catalog.balloons:
		if balloon_data.category == BalloonData.Category.NORMAL and _state.is_balloon_unlocked(balloon_data.id) and balloon_data.tier_index > current.tier_index:
			return true
	return false

func request_continue_endless() -> void:
	if not _state.endless_unlocked:
		return
	_balloon_controller.set_current_normal_balloon(&"rainbow_balloon")
	current_balloon_changed.emit(_get_current_balloon_text())
	_progression.emit_objective()
	_emit_purchase_state()
	notification_requested.emit("Endless Mode: Rainbow balloons keep scaling.")
	_save_now()

func get_completion_stats_text() -> String:
	return "Playtime: %s\nBalloons popped: %s\nClicks: %s\nTotal damage: %s\nLargest critical: %s\nCoins earned: %s\nDiamonds earned: %s\nSpecial balloons: %s" % [_format_playtime(_state.active_play_seconds), Numbers.compact(_state.balloons_popped), Numbers.compact(_state.total_clicks), Numbers.compact(_state.total_damage), Numbers.compact(_state.largest_critical), Numbers.compact(_state.coins_earned), Numbers.compact(_state.diamonds_earned), Numbers.compact(_state.special_balloons_popped)]

func is_campaign_completed() -> bool:
	return _state.campaign_completed

func get_statistics_text() -> String:
	var lines: Array[String] = []
	for id: StringName in [&"red_balloon", &"blue_balloon", &"green_balloon", &"purple_balloon", &"golden_balloon", &"rainbow_balloon"]:
		var data := _catalog.find_balloon(id)
		if data != null:
			lines.append("%s popped: %s" % [data.display_name, Numbers.compact(_state.get_balloon_pops(id))])
	lines.append("Balloon King defeated: %s" % Numbers.compact(_state.balloon_king_defeated_count))
	lines.append("Special Balloons popped: %s" % Numbers.compact(_state.special_balloons_popped))
	lines.append("Total Balloons popped: %s" % Numbers.compact(_state.balloons_popped + _state.special_balloons_popped + _state.balloon_king_defeated_count))
	return "\n".join(lines)

func get_coins() -> int:
	return _state.coins

func get_diamonds() -> int:
	return _state.diamonds

func get_click_damage() -> float:
	return _balance.get_click_damage(_state.click_damage_level)

func get_click_damage_level() -> int:
	return _state.click_damage_level

func get_next_click_upgrade_cost() -> int:
	return _upgrades.get_next_click_upgrade_cost()

func get_click_milestone_text() -> String:
	return _balance.get_click_milestone_text(_state.click_damage_level)

func get_auto_dps() -> float:
	return _equipment.get_total_auto_dps() * _globals.get_effect_multiplier(GlobalUpgradeData.Effect.AUTO_DPS) * _buffs.get_multiplier(BuffService.ELECTRIC_ID)

func get_needle_level() -> int:
	return _equipment.get_level(NEEDLE_ID)

func get_needle_dps() -> float:
	return _equipment.get_dps(NEEDLE_ID)

func get_next_needle_dps() -> float:
	if get_next_needle_cost() == 0:
		return get_needle_dps()
	return _equipment.get_dps(NEEDLE_ID, get_needle_level() + 1)

func get_next_needle_cost() -> int:
	return _equipment.get_next_cost(NEEDLE_ID)

func get_equipment_level(id: StringName) -> int:
	return _equipment.get_level(id)

func get_equipment_dps(id: StringName) -> float:
	return _equipment.get_dps(id)

func get_equipment_description(id: StringName) -> String:
	var data := _catalog.find_equipment(id)
	return data.description if data != null else ""

func get_next_equipment_dps(id: StringName) -> float:
	if get_next_equipment_cost(id) == 0:
		return get_equipment_dps(id)
	return _equipment.get_dps(id, get_equipment_level(id) + 1)

func get_next_equipment_cost(id: StringName) -> int:
	return _equipment.get_next_cost(id)

func can_buy_equipment(id: StringName) -> bool:
	return _reveal_service.is_revealed(id) and _equipment.can_buy(id)

func is_equipment_available(id: StringName) -> bool:
	return _reveal_service.is_revealed(id) and _equipment.is_available(id)

func get_equipment_milestone_text(id: StringName) -> String:
	return _equipment.get_milestone_text(id)

func get_critical_chance_level() -> int:
	return _state.critical_chance_level

func get_critical_chance() -> float:
	return _balance.get_critical_chance(_state.critical_chance_level)

func get_next_critical_chance_cost() -> int:
	return _upgrades.get_next_critical_chance_upgrade_cost()

func can_buy_critical_chance() -> bool:
	return _reveal_service.is_revealed(CRITICAL_CHANCE_ID) and _upgrades.can_buy_critical_chance()

func get_critical_damage_level() -> int:
	return _state.critical_damage_level

func get_critical_damage_multiplier() -> float:
	return _balance.get_critical_damage_multiplier(_state.critical_damage_level)

func get_next_critical_damage_cost() -> int:
	return _upgrades.get_next_critical_damage_upgrade_cost()

func can_buy_critical_damage() -> bool:
	return _reveal_service.is_revealed(CRITICAL_DAMAGE_ID) and _upgrades.can_buy_critical_damage()

func get_combo_stacks() -> int:
	return _combo_stacks

func get_combo_multiplier() -> float:
	return 1.0 + (_balance.get_combo_multiplier(_combo_stacks) - 1.0) * _globals.get_effect_multiplier(GlobalUpgradeData.Effect.COMBO_POWER)

func get_reveal_state(id: StringName) -> RevealService.RevealState:
	match id:
		CLICK_DAMAGE_ID:
			return _reveal_service.get_state(id, false, can_buy_click_damage())
		NEEDLE_ID, DART_ID, DART_LAUNCHER_ID, PRESSURE_GUN_ID, POPPING_MACHINE_ID, POPBOT_ID, CANNON_ID:
			return _reveal_service.get_state(id, get_equipment_level(id) > 0, _equipment.can_buy(id))
		CRITICAL_CHANCE_ID:
			return _reveal_service.get_state(id, get_critical_chance_level() > 0, _upgrades.can_buy_critical_chance())
		CRITICAL_DAMAGE_ID:
			return _reveal_service.get_state(id, get_critical_damage_level() > 0, _upgrades.can_buy_critical_damage())
		COMBO_ID:
			return _reveal_service.get_state(id, false, true)
		GLOBAL_UPGRADES_ID:
			return _reveal_service.get_state(id, false, _state.diamonds > 0)
	return RevealService.RevealState.HIDDEN

func can_buy_click_damage() -> bool:
	return _upgrades.can_buy_click_damage()

func can_buy_needle() -> bool:
	return _equipment.can_buy(NEEDLE_ID)

func get_global_upgrade_level(id: StringName) -> int:
	return _globals.get_level(id)

func get_global_upgrade_cost(id: StringName) -> int:
	return _globals.get_next_cost(id)

func get_buff_special_pop_interval(level: int = -1) -> int:
	var frequency_level := get_global_upgrade_level(&"special_frequency") if level < 0 else level
	var data := get_global_upgrade_data(&"special_frequency")
	if data == null:
		return _catalog.balance.buff_special_pop_interval
	var multiplier := 1.0 + frequency_level * data.bonus_per_level
	return maxi(1, ceili(float(_catalog.balance.buff_special_pop_interval) / multiplier))

func can_buy_global_upgrade(id: StringName) -> bool:
	return is_global_upgrade_revealed(id) and _globals.can_buy(id)

func get_global_upgrade_data(id: StringName) -> GlobalUpgradeData:
	return _catalog.find_global_upgrade(id)

func is_global_upgrade_revealed(id: StringName) -> bool:
	var data := _catalog.find_global_upgrade(id)
	if data == null or data.legacy_only:
		return false
	if not _reveal_service.is_revealed(GLOBAL_UPGRADES_ID):
		return false
	if get_global_upgrade_level(id) > 0:
		return true
	var highest := _get_highest_unlocked_normal_balloon()
	return highest != null and highest.tier_index >= data.required_tier and (not data.requires_buff_discovery or _state.buff_frequency_unlocked)

func is_ready_for_balloon_king() -> bool:
	return _state.is_balloon_unlocked(&"rainbow_balloon") and get_equipment_level(CANNON_ID) >= 1

func refresh_presentation() -> void:
	_emit_full_state()

func _on_auto_damage_tick() -> void:
	var total_auto_dps := get_auto_dps()
	if total_auto_dps > 0.0:
		auto_attack_performed.emit()
		_balloon_controller.damage_current_balloon(AttackResult.new(_combat.calculate_auto_damage(total_auto_dps)))

func _on_autosave_timeout() -> void:
	if _save_dirty:
		_save_now()

func _on_playtime_tick() -> void:
	_statistics.record_playtime_second()
	_save_dirty = true

func _on_coins_changed(value: int) -> void:
	coins_changed.emit(value)
	_progression.emit_objective()
	_emit_purchase_state()

func _on_diamonds_changed(value: int) -> void:
	diamonds_changed.emit(value)
	_refresh_reveals()
	_emit_purchase_state()

func _on_click_damage_upgraded(_level: int, _damage: float) -> void:
	var milestone := _level % _catalog.balance.click_milestone_interval == 0
	notification_requested.emit(tr("CLICK MILESTONE! +10% Click Damage") if milestone else tr("Click Damage increased!"))
	_refresh_reveals()
	_emit_purchase_state()
	purchase_completed.emit(&"upgrade", &"click_damage", _level, milestone)

func _on_critical_chance_upgraded(_level: int, _chance: float) -> void:
	notification_requested.emit("Critical Chance increased!")
	_refresh_reveals()
	_emit_purchase_state()
	purchase_completed.emit(&"upgrade", CRITICAL_CHANCE_ID, _level, false)

func _on_critical_damage_upgraded(_level: int, _multiplier: float) -> void:
	notification_requested.emit("Critical Damage increased!")
	_emit_purchase_state()
	purchase_completed.emit(&"upgrade", CRITICAL_DAMAGE_ID, _level, false)

func _on_equipment_changed(_id: StringName, _level: int, _total_auto_dps: float) -> void:
	notification_requested.emit("%s power increased!" % String(_id).replace("_", " ").capitalize())
	_refresh_reveals()
	_progression.emit_objective()
	_emit_purchase_state()
	var data := _catalog.find_equipment(_id)
	purchase_completed.emit(&"equipment", _id, _level, data != null and data.milestone_levels.has(_level))

func _on_global_upgrade_changed(_id: StringName, _level: int) -> void:
	if _id == &"special_frequency":
		_special_scheduler.refresh_special_frequency()
	combo_changed.emit(_combo_stacks, get_combo_multiplier())
	notification_requested.emit("Global Upgrade improved!")
	global_upgrades_changed.emit()
	_emit_purchase_state()
	purchase_completed.emit(&"global", _id, _level, false)

func _on_balloon_damaged(current_health: float, max_health: float, attack_result: AttackResult) -> void:
	_statistics.record_attack(attack_result)
	_save_dirty = true
	balloon_health_changed.emit(current_health, max_health)
	if _balloon_controller.is_boss_active():
		_update_boss_phase(current_health, max_health)
	if attack_result.was_critical:
		notification_requested.emit("CRITICAL! %s damage" % Numbers.compact(attack_result.damage))

func _on_combo_timeout() -> void:
	_combo_stacks = 0
	combo_changed.emit(_combo_stacks, get_combo_multiplier())

func _on_balloon_popped(balloon_data: BalloonData) -> void:
	_economy.add_coins(_get_normal_balloon_coin_reward(balloon_data))
	_statistics.record_normal_balloon_pop()
	_progression.record_normal_pop(balloon_data)
	_refresh_reveals()
	# A tier can reveal Electric/Frenzy on this same pop. Refresh first so a pop
	# that also reaches the special threshold can start the newly revealed event.
	_special_scheduler.notify_normal_balloon_popped(_state.balloons_popped)
	_save_dirty = true

func _on_special_started(balloon_data: BalloonData) -> void:
	if _balloon_controller.is_boss_active():
		_special_scheduler.complete_active_special()
		return
	_balloon_controller.start_special(balloon_data)
	special_started_audio.emit(balloon_data.id)
	notification_requested.emit("Special event: %s!" % balloon_data.display_name)

func _on_special_expired(balloon_data: BalloonData) -> void:
	_balloon_controller.end_special()
	notification_requested.emit("%s escaped." % balloon_data.display_name)

func _on_special_balloon_popped(balloon_data: BalloonData) -> void:
	_special_scheduler.complete_active_special()
	_balloon_controller.end_special()
	_statistics.record_special_balloon_pop()
	var coin_reward := _get_special_balloon_coin_reward(balloon_data)
	if coin_reward > 0:
		_economy.add_coins(coin_reward)
	if balloon_data.diamond_reward > 0:
		_award_diamonds(balloon_data.diamond_reward)
	match balloon_data.special_effect:
		BalloonData.SpecialEffect.CRYSTAL_DIAMONDS:
			_state.crystal_balloons_popped += 1
		BalloonData.SpecialEffect.ELECTRIC_AUTODPS:
			_activate_global_buff(BuffService.ELECTRIC_ID, _catalog.balance.electric_auto_dps_multiplier, _catalog.balance.electric_buff_duration_seconds)
			_unlock_buff_frequency()
			buff_started_audio.emit()
		BalloonData.SpecialEffect.FRENZY_CLICK:
			_activate_global_buff(BuffService.FRENZY_ID, _catalog.balance.frenzy_click_multiplier, _catalog.balance.frenzy_buff_duration_seconds)
			_unlock_buff_frequency()
			buff_started_audio.emit()
	notification_requested.emit("%s popped!" % balloon_data.display_name)
	_save_dirty = true
	active_upgrades_changed.emit()
	_refresh_reveals()

func _get_normal_balloon_coin_reward(balloon_data: BalloonData) -> int:
	return roundi(balloon_data.coin_reward * _globals.get_effect_multiplier(GlobalUpgradeData.Effect.COIN_GAIN) * (1.0 + _state.coin_reward_level * _catalog.balance.coin_reward_bonus_per_level))

func _activate_global_buff(id: StringName, base_multiplier: float, duration: float) -> void:
	var power := 1.0 + (base_multiplier - 1.0) * _globals.get_effect_multiplier(GlobalUpgradeData.Effect.BUFF_POWER)
	_buffs.activate(id, power, duration * _globals.get_effect_multiplier(GlobalUpgradeData.Effect.BUFF_DURATION))

func _get_special_balloon_coin_reward(balloon_data: BalloonData) -> int:
	if balloon_data.special_effect != BalloonData.SpecialEffect.GOLDEN_COINS:
		return roundi(balloon_data.coin_reward * _globals.get_effect_multiplier(GlobalUpgradeData.Effect.COIN_GAIN))
	var normal_balloon := _catalog.find_balloon(_state.current_normal_balloon_id)
	return _get_normal_balloon_coin_reward(normal_balloon) * 3 if normal_balloon != null else balloon_data.coin_reward

func _award_diamonds(amount: int) -> void:
	if amount <= 0:
		return
	_economy.add_diamonds(amount)
	if _state.diamond_reward_level > 0 and randf() < _get_diamond_reward_bonus_chance():
		_economy.add_diamonds(1)
		notification_requested.emit("Diamond Reward granted an extra Diamond!")

func _unlock_buff_frequency() -> void:
	if _state.buff_frequency_unlocked:
		return
	_state.buff_frequency_unlocked = true
	notification_requested.emit("New discovery: Buff Frequency")
	active_upgrades_changed.emit()

func _on_objective_changed(text: String, can_unlock: bool, action_text: String) -> void:
	if is_ready_for_balloon_king() and not _state.boss_unlocked and not _state.campaign_completed:
		objective_changed.emit("Balloon King is ready.", true, "Challenge Balloon King")
	else:
		objective_changed.emit(text, can_unlock, action_text)

func _start_balloon_king() -> void:
	var king := _catalog.find_balloon(&"balloon_king")
	if king == null:
		return
	_state.boss_unlocked = true
	_state.boss_phase = 1
	_balloon_controller.start_boss(king)
	boss_started_audio.emit()
	notification_requested.emit("Balloon King: final challenge started!")
	boss_phase_changed.emit(1, _state.boss_health, king.base_health)
	_save_now()

func _update_boss_phase(health: float, max_health: float) -> void:
	var phase := 1 if health > max_health * 0.7 else 2 if health > max_health * 0.3 else 3
	if phase > _state.boss_phase:
		_state.boss_phase = phase
		notification_requested.emit("Balloon King Phase %d!" % phase)
		boss_phase_changed.emit(phase, health, max_health)

func _on_boss_popped(_balloon_data: BalloonData) -> void:
	if _state.campaign_completed:
		return
	_state.boss_health = 0.0
	_state.campaign_completed = true
	_state.campaign_completion_presented = true
	_state.endless_unlocked = true
	_state.balloon_king_defeated_count += 1
	_balloon_controller.end_boss()
	current_balloon_changed.emit(_get_current_balloon_text())
	_progression.emit_objective()
	_save_now()
	notification_requested.emit("BALLOON KING POPPED!")
	victory_requested.emit()

func _format_playtime(seconds: int) -> String:
	return "%dh %dm %ds" % [seconds / 3600, (seconds % 3600) / 60, seconds % 60]

func _on_tier_unlocked(id: StringName) -> void:
	var unlocked := _catalog.find_balloon(id)
	notification_requested.emit("%s unlocked!" % unlocked.display_name if unlocked != null else "%s unlocked!" % String(id).replace("_", " ").capitalize())
	_balloon_controller.set_current_normal_balloon(id)
	current_balloon_changed.emit(_get_current_balloon_text())
	_refresh_reveals()
	_emit_purchase_state()
	balloon_tier_unlocked.emit(id)

func _emit_full_state() -> void:
	coins_changed.emit(_state.coins)
	diamonds_changed.emit(_state.diamonds)
	_emit_purchase_state()
	_progression.emit_objective()
	current_balloon_changed.emit(_get_current_balloon_text())
	balloon_health_changed.emit(_balloon_controller.get_current_health(), _balloon_controller.get_current_max_health())
	combo_changed.emit(_combo_stacks, get_combo_multiplier())
	buffs_changed.emit(_buffs.get_active_text())
	hold_click_option_changed.emit(_hold_click_enabled)
	buy_mode_changed.emit(_buy_mode)
	reveal_states_changed.emit()
	if _save_manager.requires_recovery():
		notification_requested.emit("Save could not be loaded. The original file was preserved.")

func _emit_purchase_state() -> void:
	click_damage_changed.emit(get_click_damage(), get_click_damage_level(), get_next_click_upgrade_cost())
	auto_dps_changed.emit(get_auto_dps(), get_needle_level(), get_needle_dps(), get_next_needle_dps(), get_next_needle_cost())
	equipment_presentation_changed.emit()
	critical_presentation_changed.emit(get_critical_chance_level(), get_critical_chance(), get_next_critical_chance_cost(), get_critical_damage_level(), get_critical_damage_multiplier(), get_next_critical_damage_cost())
	reveal_states_changed.emit()

func _refresh_reveals() -> void:
	var newly_revealed := _reveal_service.refresh()
	if newly_revealed.is_empty():
		return
	for id: StringName in newly_revealed:
		var rule := _catalog.find_reveal_rule(id)
		if rule != null:
			notification_requested.emit("New discovery: %s" % rule.display_name)
		content_revealed.emit(id)
	reveal_states_changed.emit()

func _get_current_balloon_text() -> String:
	var balloon_data := _catalog.find_balloon(_state.current_normal_balloon_id)
	return "Current Balloon: %s" % balloon_data.display_name if balloon_data != null else "Current Balloon: unavailable"

func get_balloon_coin_reward(balloon_data: BalloonData) -> int:
	if balloon_data == null or balloon_data.category == BalloonData.Category.BOSS:
		return 0
	return _get_special_balloon_coin_reward(balloon_data) if balloon_data.category == BalloonData.Category.SPECIAL else _get_normal_balloon_coin_reward(balloon_data)

func _save_now() -> void:
	if _save_manager.requires_recovery():
		return
	if _save_manager.save_game_state(_state):
		_save_dirty = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _save_dirty:
		_save_now()

func _exit_tree() -> void:
	if _save_dirty and _save_manager != null:
		_save_now()

func _validate_catalog() -> bool:
	if _catalog.balloons.is_empty() or _catalog.equipment.is_empty():
		push_error("ContentCatalogData needs balloons and equipment.")
		return false
	if _catalog.reveal_rules.is_empty():
		push_error("ContentCatalogData needs reveal rules.")
		return false
	if _catalog.balance.normal_health_variations.is_empty():
		push_error("GameBalanceData needs at least one normal health variation.")
		return false
	var ids: Dictionary = {}
	for balloon_data: BalloonData in _catalog.balloons:
		if balloon_data == null or balloon_data.id.is_empty() or balloon_data.base_health <= 0.0 or balloon_data.coin_reward < 0:
			push_error("Invalid BalloonData in catalog.")
			return false
		if ids.has(balloon_data.id):
			push_error("Duplicate content id: %s" % balloon_data.id)
			return false
		ids[balloon_data.id] = true
	for equipment_data: EquipmentData in _catalog.equipment:
		if equipment_data == null or equipment_data.id.is_empty() or equipment_data.base_cost <= 0 or equipment_data.base_dps < 0.0:
			push_error("Invalid EquipmentData in catalog.")
			return false
		if ids.has(equipment_data.id):
			push_error("Duplicate content id: %s" % equipment_data.id)
			return false
		ids[equipment_data.id] = true
	var reveal_ids: Dictionary = {}
	for reveal_rule: RevealRuleData in _catalog.reveal_rules:
		if reveal_rule == null or reveal_rule.id.is_empty() or reveal_ids.has(reveal_rule.id):
			push_error("Invalid or duplicate reveal rule: %s" % String(reveal_rule.id) if reveal_rule != null else "null")
			return false
		reveal_ids[reveal_rule.id] = true
	if _catalog.find_balloon(&"red_balloon") == null or _catalog.find_balloon(&"golden_balloon") == null or _catalog.find_equipment(DART_LAUNCHER_ID) == null or _catalog.find_equipment(PRESSURE_GUN_ID) == null:
		push_error("This milestone requires campaign and midgame content data.")
		return false
	return true
