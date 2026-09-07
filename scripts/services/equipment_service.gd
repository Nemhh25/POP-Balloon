class_name EquipmentService
extends RefCounted

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

func is_available(id: StringName) -> bool:
	var equipment_data := _catalog.find_equipment(id)
	return equipment_data != null and _state.click_damage_level >= equipment_data.required_click_damage_level

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
		total += _balance.get_equipment_dps(equipment_data, get_level(equipment_data.id))
	return total

