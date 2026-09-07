class_name EconomyService
extends RefCounted

signal coins_changed(value: int)

var _state: GameState

func _init(state: GameState) -> void:
	_state = state

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	_state.coins += amount
	_state.coins_earned += amount
	coins_changed.emit(_state.coins)

func try_spend_coins(amount: int) -> bool:
	if amount <= 0 or _state.coins < amount:
		return false
	_state.coins -= amount
	coins_changed.emit(_state.coins)
	return true

