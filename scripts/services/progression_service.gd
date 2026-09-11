class_name ProgressionService
extends RefCounted

const Numbers = preload("res://scripts/ui/number_format.gd")

signal objective_changed(text: String, can_unlock: bool, action_text: String)
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

func can_unlock_next_balloon() -> bool:
	var next := get_next_locked_balloon()
	var prerequisite := get_prerequisite_balloon(next)
	if next == null or prerequisite == null:
		return false
	if _state.get_balloon_pops(prerequisite.id) < next.unlock_pop_requirement or _state.coins < next.unlock_coin_requirement:
		return false
	return next.unlock_required_equipment_id.is_empty() or _state.get_equipment_level(next.unlock_required_equipment_id) >= next.unlock_required_equipment_level

func try_unlock_next_balloon() -> bool:
	var next := get_next_locked_balloon()
	if next == null or not can_unlock_next_balloon():
		return false
	if not _economy.try_spend_coins(next.unlock_coin_requirement):
		return false
	_state.unlock_balloon(next.id)
	tier_unlocked.emit(next.id)
	emit_objective()
	return true

func emit_objective() -> void:
	var next := get_next_locked_balloon()
	if next == null:
		objective_changed.emit("All currently configured unlocks are complete.", false, "")
		return
	var prerequisite := get_prerequisite_balloon(next)
	if prerequisite == null:
		objective_changed.emit("Content configuration error: missing prerequisite for %s." % next.display_name, false, "")
		return
	var text := "Next: %s — %s/%s %s pops · %s/%s Coins" % [next.display_name, Numbers.compact(_state.get_balloon_pops(prerequisite.id)), Numbers.compact(next.unlock_pop_requirement), prerequisite.display_name, Numbers.compact(_state.coins), Numbers.compact(next.unlock_coin_requirement)]
	if not next.unlock_required_equipment_id.is_empty():
		text += " · %s Lv. %d" % [String(next.unlock_required_equipment_id).replace("_", " ").capitalize(), next.unlock_required_equipment_level]
	objective_changed.emit(text, can_unlock_next_balloon(), "Unlock %s" % next.display_name)

func get_next_locked_balloon() -> BalloonData:
	for balloon_data: BalloonData in _catalog.balloons:
		if balloon_data.category == BalloonData.Category.NORMAL and not _state.is_balloon_unlocked(balloon_data.id):
			return balloon_data
	return null

func get_prerequisite_balloon(next: BalloonData) -> BalloonData:
	if next == null:
		return null
	var previous: BalloonData = null
	for balloon_data: BalloonData in _catalog.balloons:
		if balloon_data.category == BalloonData.Category.NORMAL and balloon_data.tier_index < next.tier_index and (previous == null or balloon_data.tier_index > previous.tier_index):
			previous = balloon_data
	return previous
