class_name ProgressionService
extends RefCounted

signal objective_changed(text: String, can_unlock: bool)
signal tier_unlocked(id: StringName)

var _state: GameState
var _catalog: ContentCatalogData
var _economy: EconomyService

func _init(state: GameState, catalog: ContentCatalogData, economy: EconomyService) -> void:
	_state = state
	_catalog = catalog
	_economy = economy

func record_normal_pop(balloon_data: BalloonData) -> void:
	_state.record_balloon_pop(balloon_data.id)
	emit_objective()

func can_unlock_blue() -> bool:
	var blue := _catalog.find_balloon(&"blue_balloon")
	if blue == null or _state.is_balloon_unlocked(blue.id):
		return false
	return _state.get_balloon_pops(&"red_balloon") >= blue.unlock_pop_requirement and _state.coins >= blue.unlock_coin_requirement

func try_unlock_blue() -> bool:
	var blue := _catalog.find_balloon(&"blue_balloon")
	if blue == null or not can_unlock_blue():
		return false
	if not _economy.try_spend_coins(blue.unlock_coin_requirement):
		return false
	_state.unlock_balloon(blue.id)
	_state.current_balloon_id = blue.id
	_state.current_balloon_health = 0.0
	tier_unlocked.emit(blue.id)
	emit_objective()
	return true

func emit_objective() -> void:
	var blue := _catalog.find_balloon(&"blue_balloon")
	if blue == null:
		objective_changed.emit("Content configuration error: Blue Balloon is missing.", false)
		return
	if _state.is_balloon_unlocked(blue.id):
		objective_changed.emit("Blue Balloon unlocked — vertical slice complete.", false)
		return
	var red_pops := _state.get_balloon_pops(&"red_balloon")
	var text := "Unlock Blue: %d/%d Red pops · %d/%d Coins" % [red_pops, blue.unlock_pop_requirement, _state.coins, blue.unlock_coin_requirement]
	objective_changed.emit(text, can_unlock_blue())

