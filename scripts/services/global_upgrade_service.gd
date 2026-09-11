class_name GlobalUpgradeService
extends RefCounted

signal global_upgrade_changed(id: StringName, level: int)

var _state: GameState
var _catalog: ContentCatalogData
var _economy: EconomyService

func _init(state: GameState, catalog: ContentCatalogData, economy: EconomyService) -> void:
	_state = state
	_catalog = catalog
	_economy = economy

func get_level(id: StringName) -> int:
	return _state.get_global_upgrade_level(id)

func get_next_cost(id: StringName) -> int:
	var data := _catalog.find_global_upgrade(id)
	if data == null or get_level(id) >= data.max_level:
		return 0
	return data.cost_at_level(get_level(id))

func can_buy(id: StringName) -> bool:
	var cost := get_next_cost(id)
	return cost > 0 and _state.diamonds >= cost

func try_buy(id: StringName) -> bool:
	var cost := get_next_cost(id)
	if cost == 0 or not _economy.try_spend_diamonds(cost):
		return false
	var level := get_level(id) + 1
	_state.set_global_upgrade_level(id, level)
	global_upgrade_changed.emit(id, level)
	return true

func get_effect_multiplier(effect: GlobalUpgradeData.Effect) -> float:
	var bonus := 0.0
	for data: GlobalUpgradeData in _catalog.global_upgrades:
		if data.effect == effect:
			bonus += get_level(data.id) * data.bonus_per_level
	return 1.0 + bonus
