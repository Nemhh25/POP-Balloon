class_name StatisticsService
extends RefCounted

var _state: GameState

func _init(state: GameState) -> void:
	_state = state

func record_click() -> void:
	_state.total_clicks += 1

func record_normal_balloon_pop() -> void:
	_state.balloons_popped += 1

func record_special_balloon_pop() -> void:
	_state.special_balloons_popped += 1

func record_damage(amount: float) -> void:
	_state.record_damage(amount)

func record_attack(attack_result: AttackResult) -> void:
	_state.record_damage(attack_result.damage)
	if attack_result.was_critical:
		_state.largest_critical = maxf(_state.largest_critical, attack_result.damage)

func record_playtime_second() -> void:
	_state.active_play_seconds += 1
