class_name GameState
extends RefCounted

var coins: int = 0
var diamonds: int = 0
var click_damage_level: int = 1
var equipment_levels: Dictionary = {}
var balloon_pops_by_id: Dictionary = {}
var unlocked_balloon_ids: Dictionary = {&"red_balloon": true}
var current_balloon_id: StringName = &"red_balloon"
var current_balloon_health: float = 0.0
var normal_variation_index: int = 0
var total_clicks: int = 0
var balloons_popped: int = 0
var coins_earned: int = 0

func get_equipment_level(id: StringName) -> int:
	return int(equipment_levels.get(id, 0))

func set_equipment_level(id: StringName, level: int) -> void:
	equipment_levels[id] = level

func get_balloon_pops(id: StringName) -> int:
	return int(balloon_pops_by_id.get(id, 0))

func record_balloon_pop(id: StringName) -> void:
	balloon_pops_by_id[id] = get_balloon_pops(id) + 1
	balloons_popped += 1

func is_balloon_unlocked(id: StringName) -> bool:
	return bool(unlocked_balloon_ids.get(id, false))

func unlock_balloon(id: StringName) -> void:
	unlocked_balloon_ids[id] = true

