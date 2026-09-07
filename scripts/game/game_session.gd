class_name GameSession
extends Node

signal coins_changed(value: int)
signal click_damage_changed(value: float, next_cost: int)
signal auto_dps_changed(value: float, needle_level: int, next_cost: int)
signal balloon_health_changed(current_health: float, max_health: float)
signal objective_changed(text: String, can_unlock: bool)
signal notification_requested(text: String)

const NEEDLE_ID := &"needle"

var _catalog: ContentCatalogData
var _state: GameState
var _balance: BalanceService
var _economy: EconomyService
var _upgrades: UpgradeService
var _equipment: EquipmentService
var _progression: ProgressionService
var _combat: CombatResolver
var _balloon_controller: BalloonController
var _auto_damage_timer: Timer

func initialize(catalog: ContentCatalogData, balloon_scene: PackedScene, balloon_container: Control) -> void:
	assert(catalog != null and catalog.balance != null, "ContentCatalogData and GameBalanceData are required.")
	_catalog = catalog
	if not _validate_catalog():
		return
	_state = GameState.new()
	_balance = BalanceService.new(_catalog.balance)
	_economy = EconomyService.new(_state)
	_upgrades = UpgradeService.new(_state, _balance, _economy)
	_equipment = EquipmentService.new(_state, _catalog, _balance, _economy)
	_progression = ProgressionService.new(_state, _catalog, _economy)
	_combat = CombatResolver.new(_balance)

	_economy.coins_changed.connect(_on_coins_changed)
	_upgrades.click_damage_upgraded.connect(_on_click_damage_upgraded)
	_equipment.equipment_changed.connect(_on_equipment_changed)
	_progression.objective_changed.connect(_on_objective_changed)
	_progression.tier_unlocked.connect(_on_tier_unlocked)

	_balloon_controller = BalloonController.new()
	add_child(_balloon_controller)
	_balloon_controller.setup(_catalog, _state, _balance, balloon_scene, balloon_container)
	_balloon_controller.balloon_clicked.connect(handle_balloon_click)
	_balloon_controller.balloon_damaged.connect(_on_balloon_damaged)
	_balloon_controller.balloon_popped.connect(_on_balloon_popped)

	_auto_damage_timer = Timer.new()
	_auto_damage_timer.wait_time = _balance.get_auto_damage_tick_interval()
	_auto_damage_timer.timeout.connect(_on_auto_damage_tick)
	add_child(_auto_damage_timer)
	_auto_damage_timer.start()

	_balloon_controller.spawn_current_normal(true)
	_emit_full_state()

func handle_balloon_click() -> void:
	_state.total_clicks += 1
	_balloon_controller.damage_current_balloon(_combat.calculate_manual_attack(_state))

func request_click_upgrade() -> void:
	if not _upgrades.try_buy_click_damage():
		notification_requested.emit("Not enough Coins for Click Damage.")

func request_needle_upgrade() -> void:
	if not _equipment.try_buy(NEEDLE_ID):
		notification_requested.emit("Upgrade Click Damage first, or earn more Coins.")

func request_unlock_blue() -> void:
	if not _progression.try_unlock_blue():
		notification_requested.emit("Blue Balloon requirements are not met yet.")

func get_coins() -> int:
	return _state.coins

func get_click_damage() -> float:
	return _balance.get_click_damage(_state.click_damage_level)

func get_next_click_upgrade_cost() -> int:
	return _upgrades.get_next_click_upgrade_cost()

func get_auto_dps() -> float:
	return _equipment.get_total_auto_dps()

func get_needle_level() -> int:
	return _equipment.get_level(NEEDLE_ID)

func get_next_needle_cost() -> int:
	return _equipment.get_next_cost(NEEDLE_ID)

func can_buy_click_damage() -> bool:
	return _upgrades.can_buy_click_damage()

func can_buy_needle() -> bool:
	return _equipment.can_buy(NEEDLE_ID)

func refresh_presentation() -> void:
	_emit_full_state()

func _on_auto_damage_tick() -> void:
	var total_auto_dps := _equipment.get_total_auto_dps()
	if total_auto_dps <= 0.0:
		return
	var damage := _combat.calculate_auto_damage(total_auto_dps)
	_balloon_controller.damage_current_balloon(AttackResult.new(damage))

func _on_coins_changed(value: int) -> void:
	coins_changed.emit(value)
	_progression.emit_objective()
	_emit_purchase_state()

func _on_click_damage_upgraded(_level: int, _damage: float) -> void:
	notification_requested.emit("Click Damage increased!")
	_emit_purchase_state()

func _on_equipment_changed(_id: StringName, _level: int, _total_auto_dps: float) -> void:
	notification_requested.emit("Needle power increased!")
	_emit_purchase_state()

func _on_balloon_damaged(current_health: float, max_health: float, _attack_result: AttackResult) -> void:
	balloon_health_changed.emit(current_health, max_health)

func _on_balloon_popped(balloon_data: BalloonData) -> void:
	_economy.add_coins(balloon_data.coin_reward)
	_progression.record_normal_pop(balloon_data)

func _on_objective_changed(text: String, can_unlock: bool) -> void:
	objective_changed.emit(text, can_unlock)

func _on_tier_unlocked(id: StringName) -> void:
	notification_requested.emit("%s unlocked!" % String(id).replace("_", " ").capitalize())
	_balloon_controller.spawn_current_normal(true)

func _emit_full_state() -> void:
	coins_changed.emit(_state.coins)
	_emit_purchase_state()
	_progression.emit_objective()
	balloon_health_changed.emit(_balloon_controller.get_current_health(), _balloon_controller.get_current_max_health())

func _emit_purchase_state() -> void:
	click_damage_changed.emit(get_click_damage(), get_next_click_upgrade_cost())
	auto_dps_changed.emit(get_auto_dps(), get_needle_level(), get_next_needle_cost())

func _validate_catalog() -> bool:
	if _catalog.balloons.is_empty() or _catalog.equipment.is_empty():
		push_error("ContentCatalogData needs balloons and equipment.")
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
	if _catalog.find_balloon(&"red_balloon") == null or _catalog.find_balloon(&"blue_balloon") == null or _catalog.find_equipment(NEEDLE_ID) == null:
		push_error("The vertical slice requires Red Balloon, Blue Balloon, and Needle data.")
		return false
	return true
