class_name EconomyService
extends RefCounted

signal coins_changed(value: int)
signal diamonds_changed(value: int)

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

func add_diamonds(amount: int) -> void:
	if amount <= 0:
		return
	_state.diamonds += amount
	_state.diamonds_earned += amount
	diamonds_changed.emit(_state.diamonds)

func try_spend_diamonds(amount: int) -> bool:
	if amount <= 0 or _state.diamonds < amount:
		return false
	_state.diamonds -= amount
	diamonds_changed.emit(_state.diamonds)
	return true
