class_name CombatResolver
extends RefCounted

var _balance: BalanceService
var _random := RandomNumberGenerator.new()

func _init(balance: BalanceService) -> void:
	_balance = balance

func calculate_manual_attack(state: GameState, combo_multiplier: float = 1.0, click_multiplier: float = 1.0, critical_multiplier_bonus: float = 1.0) -> AttackResult:
	var was_critical := _random.randf() < _balance.get_critical_chance(state.critical_chance_level)
	var critical_multiplier := _balance.get_critical_damage_multiplier(state.critical_damage_level) * critical_multiplier_bonus if was_critical else 1.0
	var damage := maxf(0.25, _balance.get_click_damage(state.click_damage_level) * combo_multiplier * click_multiplier * critical_multiplier)
	return AttackResult.new(damage, was_critical, combo_multiplier, true)

func calculate_auto_damage(total_auto_dps: float) -> float:
	return total_auto_dps * _balance.get_auto_damage_tick_interval()
