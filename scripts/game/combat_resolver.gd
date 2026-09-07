class_name CombatResolver
extends RefCounted

var _balance: BalanceService

func _init(balance: BalanceService) -> void:
	_balance = balance

func calculate_manual_attack(state: GameState) -> AttackResult:
	return AttackResult.new(_balance.get_click_damage(state.click_damage_level))

func calculate_auto_damage(total_auto_dps: float) -> float:
	return total_auto_dps * _balance.get_auto_damage_tick_interval()

