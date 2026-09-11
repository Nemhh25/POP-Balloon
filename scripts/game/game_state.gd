class_name GameState
extends RefCounted

const SAVE_VERSION := 10
const PREVIOUS_SAVE_VERSION_9 := 9
const PREVIOUS_SAVE_VERSION_8 := 8
const PREVIOUS_SAVE_VERSION_7 := 7
const PREVIOUS_SAVE_VERSION_6 := 6
const PREVIOUS_SAVE_VERSION_5 := 5
const PREVIOUS_SAVE_VERSION_4 := 4
const PREVIOUS_SAVE_VERSION := 3
const FIELD_SAVE_VERSION := 2
const LEGACY_SAVE_VERSION := 1

var coins: int = 0
var diamonds: int = 0
var click_damage_level: int = 1
var critical_chance_level: int = 0
var critical_damage_level: int = 0
var coin_reward_level: int = 0
var diamond_reward_level: int = 0
var diamond_event_frequency_level: int = 0
var buff_frequency_level: int = 0
var buff_frequency_clicks: int = 0
var diamond_progress_pops: int = 0
var crystal_balloons_popped: int = 0
var buff_frequency_unlocked := false
var equipment_levels: Dictionary = {}
var global_upgrade_levels: Dictionary = {}

var current_normal_balloon_id: StringName = &"red_balloon"
var current_balloon_health := 0.0
var normal_variation_index := 0

var balloon_pops_by_id: Dictionary = {}
var unlocked_balloon_ids: Dictionary = {&"red_balloon": true}
var boss_unlocked := false
var campaign_completed := false
var campaign_completion_presented := false
var endless_unlocked := false
var boss_health := 0.0
var boss_phase: int = 0

var total_clicks: int = 0
var balloons_popped: int = 0
var special_balloons_popped: int = 0
var coins_earned: int = 0
var diamonds_earned: int = 0
var total_damage := 0.0
var largest_critical := 0.0
var active_play_seconds: int = 0
var balloon_king_defeated_count: int = 0

var master_volume := 1.0
var music_volume := 1.0
var sfx_volume := 1.0
var hold_click_enabled := false

func get_equipment_level(id: StringName) -> int:
	return int(equipment_levels.get(id, 0))

func set_equipment_level(id: StringName, level: int) -> void:
	equipment_levels[id] = level

func get_global_upgrade_level(id: StringName) -> int:
	return int(global_upgrade_levels.get(id, 0))

func set_global_upgrade_level(id: StringName, level: int) -> void:
	global_upgrade_levels[id] = level

func get_balloon_pops(id: StringName) -> int:
	return int(balloon_pops_by_id.get(id, 0))

func record_balloon_pop(id: StringName) -> void:
	balloon_pops_by_id[id] = get_balloon_pops(id) + 1

func record_damage(amount: float) -> void:
	if amount > 0.0:
		total_damage += amount

func is_balloon_unlocked(id: StringName) -> bool:
	return bool(unlocked_balloon_ids.get(id, false))

func unlock_balloon(id: StringName) -> void:
	unlocked_balloon_ids[id] = true

func to_save_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"currency": {"coins": coins, "diamonds": diamonds},
		"upgrades": {
			"click_damage_level": click_damage_level,
			"critical_chance_level": critical_chance_level,
			"critical_damage_level": critical_damage_level,
			"coin_reward_level": coin_reward_level, "diamond_reward_level": diamond_reward_level, "diamond_event_frequency_level": diamond_event_frequency_level, "buff_frequency_level": buff_frequency_level, "buff_frequency_clicks": buff_frequency_clicks,
			"diamond_progress_pops": diamond_progress_pops,
			"crystal_balloons_popped": crystal_balloons_popped,
			"buff_frequency_unlocked": buff_frequency_unlocked,
		},
		"equipment_levels": _serialize_int_dictionary(equipment_levels),
		"global_upgrade_levels": _serialize_int_dictionary(global_upgrade_levels),
		"progression": {
			"current_normal_balloon_id": String(current_normal_balloon_id),
			"current_balloon_health": current_balloon_health,
			"normal_variation_index": normal_variation_index,
			"unlocked_balloon_ids": _serialize_id_dictionary(unlocked_balloon_ids),
			"balloon_pops_by_id": _serialize_int_dictionary(balloon_pops_by_id),
			"boss_unlocked": boss_unlocked,
			"campaign_completed": campaign_completed,
			"campaign_completion_presented": campaign_completion_presented,
			"endless_unlocked": endless_unlocked,
			"boss_health": boss_health,
			"boss_phase": boss_phase,
		},
		"statistics": {
			"clicks": total_clicks,
			"balloons_popped": balloons_popped,
			"special_balloons_popped": special_balloons_popped,
			"coins_earned": coins_earned,
			"diamonds_earned": diamonds_earned,
			"total_damage": total_damage,
			"largest_critical": largest_critical,
			"active_play_seconds": active_play_seconds,
			"balloon_king_defeated_count": balloon_king_defeated_count,
		},
		"settings": {
			"master_volume": master_volume,
			"music_volume": music_volume,
			"sfx_volume": sfx_volume,
			"hold_click_enabled": hold_click_enabled,
		},
	}

static func from_save_data(raw_data: Variant, catalog: ContentCatalogData) -> GameState:
	if typeof(raw_data) != TYPE_DICTIONARY or catalog == null:
		return null
	var data: Dictionary = raw_data
	if not _has_int(data, "save_version"):
		return null
	var version := int(data["save_version"])
	if version == LEGACY_SAVE_VERSION:
		data = _migrate_v1(data, catalog)
	elif version == FIELD_SAVE_VERSION:
		data = _migrate_v2_field(data, catalog)
	elif version == PREVIOUS_SAVE_VERSION or version == PREVIOUS_SAVE_VERSION_4:
		data = _migrate_v3(data)
	elif version == PREVIOUS_SAVE_VERSION_5:
		data = _migrate_v5(data, catalog)
	elif version == PREVIOUS_SAVE_VERSION_6:
		data = _migrate_v6(data)
	elif version == PREVIOUS_SAVE_VERSION_7:
		data = _migrate_v7(data)
	elif version == PREVIOUS_SAVE_VERSION_8:
		data = _migrate_v8(data)
	elif version == PREVIOUS_SAVE_VERSION_9:
		data = _migrate_v9(data)
	elif version != SAVE_VERSION:
		return null
	return _load_v2(data, catalog)

static func _migrate_v9(v9_data: Dictionary) -> Dictionary:
	var migrated := v9_data.duplicate(true)
	migrated["save_version"] = SAVE_VERSION
	var upgrades: Dictionary = migrated.get("upgrades", {})
	upgrades["diamond_event_frequency_level"] = 0
	migrated["upgrades"] = upgrades
	var progression: Dictionary = migrated.get("progression", {})
	progression["campaign_completion_presented"] = bool(progression.get("campaign_completed", false))
	migrated["progression"] = progression
	var statistics: Dictionary = migrated.get("statistics", {})
	statistics["balloon_king_defeated_count"] = 1 if bool(progression.get("campaign_completed", false)) else 0
	migrated["statistics"] = statistics
	var settings: Dictionary = migrated.get("settings", {})
	settings["hold_click_enabled"] = false
	migrated["settings"] = settings
	return migrated

static func _migrate_v1(v1_data: Dictionary, catalog: ContentCatalogData) -> Dictionary:
	var migrated := v1_data.duplicate(true)
	migrated["save_version"] = SAVE_VERSION
	var progression: Dictionary = migrated.get("progression", {})
	progression["boss_health"] = 0.0
	progression["boss_phase"] = 0
	if not _has_valid_current_balloon(progression, catalog):
		_set_default_current_balloon(progression, catalog)
	migrated["progression"] = progression
	migrated["global_upgrade_levels"] = {}
	return migrated

static func _migrate_v2_field(v2_data: Dictionary, catalog: ContentCatalogData) -> Dictionary:
	var migrated := v2_data.duplicate(true)
	migrated["save_version"] = SAVE_VERSION
	var progression: Dictionary = migrated.get("progression", {})
	progression["boss_health"] = 0.0
	progression["boss_phase"] = 0
	_set_default_current_balloon(progression, catalog)
	migrated["progression"] = progression
	migrated["global_upgrade_levels"] = {}
	return migrated

static func _migrate_v3(v3_data: Dictionary) -> Dictionary:
	var migrated := v3_data.duplicate(true)
	migrated["save_version"] = SAVE_VERSION
	migrated["global_upgrade_levels"] = {}
	var progression: Dictionary = migrated.get("progression", {})
	progression["boss_health"] = 0.0
	progression["boss_phase"] = 0
	migrated["progression"] = progression
	return migrated

static func _migrate_v5(v5_data: Dictionary, catalog: ContentCatalogData) -> Dictionary:
	var migrated := v5_data.duplicate(true)
	migrated["save_version"] = SAVE_VERSION
	var upgrades: Dictionary = migrated.get("upgrades", {})
	upgrades["critical_chance_level"] = mini(int(upgrades.get("critical_chance_level", 0)), catalog.balance.critical_chance_max_level)
	upgrades["critical_damage_level"] = mini(int(upgrades.get("critical_damage_level", 0)), catalog.balance.critical_damage_max_level)
	migrated["upgrades"] = upgrades
	return migrated

static func _migrate_v6(v6_data: Dictionary) -> Dictionary:
	var migrated := v6_data.duplicate(true)
	migrated["save_version"] = SAVE_VERSION
	var upgrades: Dictionary = migrated.get("upgrades", {})
	upgrades["coin_reward_level"] = 0
	upgrades["diamond_reward_level"] = 0
	upgrades["buff_frequency_level"] = 0
	upgrades["buff_frequency_clicks"] = 0
	migrated["upgrades"] = upgrades
	return migrated

static func _migrate_v7(v7_data: Dictionary) -> Dictionary:
	var migrated := v7_data.duplicate(true)
	migrated["save_version"] = SAVE_VERSION
	var upgrades: Dictionary = migrated.get("upgrades", {})
	upgrades["diamond_progress_pops"] = 0
	migrated["upgrades"] = upgrades
	return migrated

static func _migrate_v8(v8_data: Dictionary) -> Dictionary:
	var migrated := v8_data.duplicate(true)
	migrated["save_version"] = SAVE_VERSION
	var upgrades: Dictionary = migrated.get("upgrades", {})
	upgrades["crystal_balloons_popped"] = 0
	upgrades["buff_frequency_unlocked"] = false
	migrated["upgrades"] = upgrades
	return migrated

static func _load_v2(data: Dictionary, catalog: ContentCatalogData) -> GameState:
	var currency := _required_dictionary(data, "currency")
	var upgrades := _required_dictionary(data, "upgrades")
	var equipment := _required_dictionary(data, "equipment_levels")
	var global_upgrades := _required_dictionary(data, "global_upgrade_levels")
	var progression := _required_dictionary(data, "progression")
	var statistics := _required_dictionary(data, "statistics")
	var settings := _required_dictionary(data, "settings")
	if currency.is_empty() or upgrades.is_empty() or progression.is_empty() or statistics.is_empty() or settings.is_empty():
		return null
	if not _has_non_negative_int(currency, "coins") or not _has_non_negative_int(currency, "diamonds"):
		return null
	if not _has_int_in_range(upgrades, "click_damage_level", 1, catalog.balance.click_upgrade_max_level if catalog.balance.click_upgrade_max_level > 0 else 2147483647):
		return null
	if not _has_int_in_range(upgrades, "critical_chance_level", 0, catalog.balance.critical_chance_max_level) or not _has_int_in_range(upgrades, "critical_damage_level", 0, catalog.balance.critical_damage_max_level):
		return null
	if not _has_bool(progression, "boss_unlocked") or not _has_bool(progression, "campaign_completed") or not _has_bool(progression, "endless_unlocked") or not _has_non_negative_number(progression, "boss_health") or not _has_int_in_range(progression, "boss_phase", 0, 3):
		return null
	if not _has_valid_current_balloon(progression, catalog):
		return null
	if typeof(progression.get("unlocked_balloon_ids")) != TYPE_ARRAY or typeof(progression.get("balloon_pops_by_id")) != TYPE_DICTIONARY:
		return null
	if not _has_non_negative_int(statistics, "clicks") or not _has_non_negative_int(statistics, "balloons_popped") or not _has_non_negative_int(statistics, "special_balloons_popped") or not _has_non_negative_int(statistics, "coins_earned") or not _has_non_negative_int(statistics, "diamonds_earned") or not _has_non_negative_number(statistics, "total_damage") or not _has_non_negative_number(statistics, "largest_critical") or not _has_non_negative_int(statistics, "active_play_seconds"):
		return null
	if not _has_number_in_range(settings, "master_volume", 0.0, 1.0) or not _has_number_in_range(settings, "music_volume", 0.0, 1.0) or not _has_number_in_range(settings, "sfx_volume", 0.0, 1.0):
		return null

	var state := GameState.new()
	state.coins = int(currency["coins"])
	state.diamonds = int(currency["diamonds"])
	state.click_damage_level = int(upgrades["click_damage_level"])
	state.critical_chance_level = int(upgrades["critical_chance_level"])
	state.critical_damage_level = int(upgrades["critical_damage_level"])
	state.coin_reward_level = clampi(int(upgrades.get("coin_reward_level", 0)), 0, catalog.balance.coin_reward_max_level)
	state.diamond_reward_level = clampi(int(upgrades.get("diamond_reward_level", 0)), 0, catalog.balance.diamond_reward_max_level)
	state.diamond_event_frequency_level = clampi(int(upgrades.get("diamond_event_frequency_level", 0)), 0, catalog.balance.diamond_event_frequency_max_level)
	state.buff_frequency_level = clampi(int(upgrades.get("buff_frequency_level", 0)), 0, catalog.balance.buff_frequency_max_level)
	state.buff_frequency_clicks = clampi(int(upgrades.get("buff_frequency_clicks", 0)), 0, catalog.balance.buff_frequency_click_requirement - 1)
	state.diamond_progress_pops = int(upgrades.get("diamond_progress_pops", 0))
	state.crystal_balloons_popped = int(upgrades.get("crystal_balloons_popped", 0))
	state.buff_frequency_unlocked = bool(upgrades.get("buff_frequency_unlocked", false))
	state.boss_unlocked = bool(progression["boss_unlocked"])
	state.campaign_completed = bool(progression["campaign_completed"])
	state.campaign_completion_presented = bool(progression.get("campaign_completion_presented", state.campaign_completed))
	state.endless_unlocked = bool(progression["endless_unlocked"])
	state.boss_health = float(progression["boss_health"])
	state.boss_phase = int(progression["boss_phase"])
	state.current_normal_balloon_id = StringName(progression["current_normal_balloon_id"])
	state.current_balloon_health = float(progression["current_balloon_health"])
	state.normal_variation_index = int(progression["normal_variation_index"])
	state.total_clicks = int(statistics["clicks"])
	state.balloons_popped = int(statistics["balloons_popped"])
	state.special_balloons_popped = int(statistics["special_balloons_popped"])
	state.coins_earned = int(statistics["coins_earned"])
	state.diamonds_earned = int(statistics["diamonds_earned"])
	state.total_damage = float(statistics["total_damage"])
	state.largest_critical = float(statistics["largest_critical"])
	state.active_play_seconds = int(statistics["active_play_seconds"])
	state.balloon_king_defeated_count = int(statistics.get("balloon_king_defeated_count", 1 if state.campaign_completed else 0))
	state.master_volume = float(settings["master_volume"])
	state.music_volume = float(settings["music_volume"])
	state.sfx_volume = float(settings["sfx_volume"])
	state.hold_click_enabled = bool(settings.get("hold_click_enabled", false))
	if not _load_known_ids(state, equipment, global_upgrades, progression["unlocked_balloon_ids"], progression["balloon_pops_by_id"], catalog):
		return null
	return state if state.is_balloon_unlocked(&"red_balloon") and state.is_balloon_unlocked(state.current_normal_balloon_id) else null

static func _has_valid_current_balloon(progression: Dictionary, catalog: ContentCatalogData) -> bool:
	if typeof(progression.get("current_normal_balloon_id")) != TYPE_STRING or not _has_non_negative_number(progression, "current_balloon_health") or not _has_non_negative_int(progression, "normal_variation_index"):
		return false
	var balloon := catalog.find_balloon(StringName(progression["current_normal_balloon_id"]))
	return balloon != null and balloon.category == BalloonData.Category.NORMAL

static func _set_default_current_balloon(progression: Dictionary, catalog: ContentCatalogData) -> void:
	var unlocked: Array = progression.get("unlocked_balloon_ids", [])
	var selected: BalloonData = catalog.find_balloon(&"red_balloon")
	for balloon_data: BalloonData in catalog.balloons:
		if balloon_data.category == BalloonData.Category.NORMAL and unlocked.has(String(balloon_data.id)) and (selected == null or balloon_data.tier_index > selected.tier_index):
			selected = balloon_data
	progression["current_normal_balloon_id"] = String(selected.id) if selected != null else "red_balloon"
	progression["current_balloon_health"] = 0.0
	progression["normal_variation_index"] = 0

static func _load_known_ids(state: GameState, raw_equipment: Dictionary, raw_global_upgrades: Dictionary, raw_unlocked: Array, raw_pops: Dictionary, catalog: ContentCatalogData) -> bool:
	for raw_id: Variant in raw_equipment:
		if typeof(raw_id) != TYPE_STRING or not _has_non_negative_int(raw_equipment, raw_id):
			return false
		var equipment_data := catalog.find_equipment(StringName(raw_id))
		if equipment_data == null or int(raw_equipment[raw_id]) > equipment_data.max_level:
			return false
		state.set_equipment_level(StringName(raw_id), int(raw_equipment[raw_id]))
	for equipment_data: EquipmentData in catalog.equipment:
		if not state.equipment_levels.has(equipment_data.id):
			state.set_equipment_level(equipment_data.id, 0)
	for raw_id: Variant in raw_global_upgrades:
		if typeof(raw_id) != TYPE_STRING or not _has_non_negative_int(raw_global_upgrades, raw_id):
			return false
		var global_data := catalog.find_global_upgrade(StringName(raw_id))
		if global_data == null or int(raw_global_upgrades[raw_id]) > global_data.max_level:
			return false
		state.set_global_upgrade_level(StringName(raw_id), int(raw_global_upgrades[raw_id]))
	for global_data: GlobalUpgradeData in catalog.global_upgrades:
		if not state.global_upgrade_levels.has(global_data.id):
			state.set_global_upgrade_level(global_data.id, 0)
	for raw_id: Variant in raw_unlocked:
		if typeof(raw_id) != TYPE_STRING or not _is_known_normal_balloon(StringName(raw_id), catalog):
			return false
		state.unlock_balloon(StringName(raw_id))
	for raw_id: Variant in raw_pops:
		if typeof(raw_id) != TYPE_STRING or not _has_non_negative_int(raw_pops, raw_id) or not _is_known_normal_balloon(StringName(raw_id), catalog):
			return false
		state.balloon_pops_by_id[StringName(raw_id)] = int(raw_pops[raw_id])
	return true

static func _is_known_normal_balloon(id: StringName, catalog: ContentCatalogData) -> bool:
	var balloon := catalog.find_balloon(id)
	return balloon != null and balloon.category == BalloonData.Category.NORMAL

static func _serialize_int_dictionary(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id: Variant in source:
		result[String(id)] = int(source[id])
	return result

static func _serialize_id_dictionary(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for id: Variant in source:
		if bool(source[id]):
			result.append(String(id))
	return result

static func _required_dictionary(data: Dictionary, key: String) -> Dictionary:
	if typeof(data.get(key)) != TYPE_DICTIONARY:
		return {}
	return data[key]

static func _has_bool(data: Dictionary, key: String) -> bool:
	return typeof(data.get(key)) == TYPE_BOOL

static func _has_int(data: Dictionary, key: String) -> bool:
	if not data.has(key) or (typeof(data[key]) != TYPE_INT and typeof(data[key]) != TYPE_FLOAT):
		return false
	return is_equal_approx(float(data[key]), float(int(data[key])))

static func _has_non_negative_int(data: Dictionary, key: String) -> bool:
	return _has_int(data, key) and int(data[key]) >= 0

static func _has_int_in_range(data: Dictionary, key: String, minimum: int, maximum: int) -> bool:
	return _has_int(data, key) and int(data[key]) >= minimum and int(data[key]) <= maximum

static func _has_non_negative_number(data: Dictionary, key: String) -> bool:
	return data.has(key) and (typeof(data[key]) == TYPE_INT or typeof(data[key]) == TYPE_FLOAT) and float(data[key]) >= 0.0

static func _has_number_in_range(data: Dictionary, key: String, minimum: float, maximum: float) -> bool:
	return _has_non_negative_number(data, key) and float(data[key]) >= minimum and float(data[key]) <= maximum
