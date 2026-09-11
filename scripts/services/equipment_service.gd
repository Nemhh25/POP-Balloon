class_name EquipmentService
extends RefCounted

const Numbers = preload("res://scripts/ui/number_format.gd")

signal equipment_changed(id: StringName, level: int, total_auto_dps: float)

var _state: GameState
var _catalog: ContentCatalogData
var _balance: BalanceService
var _economy: EconomyService

func _init(state: GameState, catalog: ContentCatalogData, balance: BalanceService, economy: EconomyService) -> void:
	_state = state
	_catalog = catalog
	_balance = balance
	_economy = economy

func get_level(id: StringName) -> int:
	return _state.get_equipment_level(id)

func get_dps(id: StringName, level: int = -1) -> float:
	var equipment_data := _catalog.find_equipment(id)
	if equipment_data == null:
		return 0.0
	var resolved_level := get_level(id) if level < 0 else level
	return _balance.get_equipment_dps(equipment_data, resolved_level)

func is_available(id: StringName) -> bool:
	var equipment_data := _catalog.find_equipment(id)
	return equipment_data != null and _state.click_damage_level >= equipment_data.required_click_damage_level and _get_highest_unlocked_balloon_tier() >= equipment_data.required_balloon_tier

func get_next_cost(id: StringName) -> int:
	var equipment_data := _catalog.find_equipment(id)
	if equipment_data == null:
		return 0
	var current_level := get_level(id)
	if current_level >= equipment_data.max_level:
		return 0
	return _balance.get_equipment_level_cost(equipment_data, current_level)

func can_buy(id: StringName) -> bool:
	var cost := get_next_cost(id)
	return is_available(id) and cost > 0 and _state.coins >= cost

func try_buy(id: StringName) -> bool:
	var equipment_data := _catalog.find_equipment(id)
	var cost := get_next_cost(id)
	if equipment_data == null or cost == 0 or not is_available(id) or not _economy.try_spend_coins(cost):
		return false
	var next_level := get_level(id) + 1
	_state.set_equipment_level(id, next_level)
	equipment_changed.emit(id, next_level, get_total_auto_dps())
	return true

func get_total_auto_dps() -> float:
	var total := 0.0
	for equipment_data: EquipmentData in _catalog.equipment:
		total += get_dps(equipment_data.id)
	return total

func get_milestone_text(id: StringName) -> String:
	var equipment_data := _catalog.find_equipment(id)
	if equipment_data == null or equipment_data.milestone_levels.is_empty():
		return "No milestones"
	var parts: Array[String] = []
	var milestone_count := mini(equipment_data.milestone_levels.size(), equipment_data.milestone_multipliers.size())
	for index in milestone_count:
		var level := equipment_data.milestone_levels[index]
		var multiplier := equipment_data.milestone_multipliers[index]
		var marker := "✓" if get_level(id) >= level else ""
		parts.append("%sLv.%d ×%s" % [marker, level, _format_multiplier(multiplier)])
	return "Milestones: %s" % " · ".join(parts)

func _get_highest_unlocked_balloon_tier() -> int:
	var highest_tier := 0
	for balloon_data: BalloonData in _catalog.balloons:
		if balloon_data.category == BalloonData.Category.NORMAL and _state.is_balloon_unlocked(balloon_data.id):
			highest_tier = maxi(highest_tier, balloon_data.tier_index)
	return highest_tier

func _format_multiplier(value: float) -> String:
	return Numbers.decimal(value)
