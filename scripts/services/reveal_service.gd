class_name RevealService
extends RefCounted

enum RevealState {
	HIDDEN,
	REVEALED_LOCKED,
	AVAILABLE,
	OWNED,
}

var _state: GameState
var _catalog: ContentCatalogData
var _revealed: Dictionary = {}

func _init(state: GameState, catalog: ContentCatalogData) -> void:
	_state = state
	_catalog = catalog

func initialize() -> void:
	for rule: RevealRuleData in _catalog.reveal_rules:
		_revealed[rule.id] = _meets_requirement(rule)

func refresh() -> Array[StringName]:
	var newly_revealed: Array[StringName] = []
	for rule: RevealRuleData in _catalog.reveal_rules:
		var is_revealed := _meets_requirement(rule)
		if is_revealed and not bool(_revealed.get(rule.id, false)):
			newly_revealed.append(rule.id)
		_revealed[rule.id] = is_revealed
	return newly_revealed

func is_revealed(id: StringName) -> bool:
	return bool(_revealed.get(id, false))

func get_state(id: StringName, is_owned: bool, can_purchase: bool) -> RevealState:
	if not is_revealed(id):
		return RevealState.HIDDEN
	if is_owned:
		return RevealState.OWNED
	return RevealState.AVAILABLE if can_purchase else RevealState.REVEALED_LOCKED

func _meets_requirement(rule: RevealRuleData) -> bool:
	if rule.required_click_damage_level > _state.click_damage_level:
		return false
	if rule.required_critical_chance_level > _state.critical_chance_level:
		return false
	if rule.required_balloon_tier > _get_highest_unlocked_balloon_tier():
		return false
	if not rule.required_equipment_id.is_empty() and _state.get_equipment_level(rule.required_equipment_id) < rule.required_equipment_level:
		return false
	if not rule.required_balloon_pop_id.is_empty() and _state.get_balloon_pops(rule.required_balloon_pop_id) < rule.required_balloon_pop_count:
		return false
	# Discovery of the currency survives spending the last Diamond.
	var discovered_diamonds := maxi(_state.diamonds, _state.diamonds_earned) if rule.id == &"global_upgrades" else _state.diamonds
	if discovered_diamonds < rule.required_diamond_count:
		return false
	return true

func _get_highest_unlocked_balloon_tier() -> int:
	var highest_tier := 0
	for balloon_data: BalloonData in _catalog.balloons:
		if balloon_data.category == BalloonData.Category.NORMAL and _state.is_balloon_unlocked(balloon_data.id):
			highest_tier = maxi(highest_tier, balloon_data.tier_index)
	return highest_tier
