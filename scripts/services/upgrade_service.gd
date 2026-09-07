class_name UpgradeService
extends RefCounted

signal click_damage_upgraded(level: int, damage: float)

var _state: GameState
var _balance: BalanceService
var _economy: EconomyService

func _init(state: GameState, balance: BalanceService, economy: EconomyService) -> void:
	_state = state
	_balance = balance
	_economy = economy

func get_next_click_upgrade_cost() -> int:
	if _state.click_damage_level >= _balance.get_click_upgrade_max_level():
		return 0
	return _balance.get_click_upgrade_cost(_state.click_damage_level)

func can_buy_click_damage() -> bool:
	var cost := get_next_click_upgrade_cost()
	return cost > 0 and _state.coins >= cost

func try_buy_click_damage() -> bool:
	var cost := get_next_click_upgrade_cost()
	if cost == 0 or not _economy.try_spend_coins(cost):
		return false
	_state.click_damage_level += 1
	click_damage_upgraded.emit(_state.click_damage_level, _balance.get_click_damage(_state.click_damage_level))
	return true
