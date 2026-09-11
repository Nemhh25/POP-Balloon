class_name BalanceService
extends RefCounted

const Numbers = preload("res://scripts/ui/number_format.gd")

var _data: GameBalanceData

func _init(data: GameBalanceData) -> void:
	assert(data != null, "GameBalanceData is required.")
	_data = data

func get_click_damage(level: int) -> float:
	return get_base_click_damage(level) * (1.0 + get_click_milestone_count(level) * _data.click_milestone_bonus)

func get_base_click_damage(level: int) -> float:
	return _data.click_damage_base + maxf(0.0, level - 1) * _data.click_damage_per_level

func get_click_milestone_count(level: int) -> int:
	return floori(float(level) / _data.click_milestone_interval)

func get_next_click_milestone(level: int) -> int:
	return (get_click_milestone_count(level) + 1) * _data.click_milestone_interval

func get_click_milestone_text(level: int) -> String:
	var target := get_next_click_milestone(level)
	return tr("Next milestone: Lv.%d · +%s%% Click Damage\n%d levels remaining") % [target, Numbers.decimal(_data.click_milestone_bonus * 100.0), target - level]

func get_click_upgrade_cost(current_level: int) -> int:
	if current_level > 0 and current_level <= _data.early_click_upgrade_costs.size():
		return _data.early_click_upgrade_costs[current_level - 1]
	if not _data.early_click_upgrade_costs.is_empty():
		return round_to_nearest_five(_data.click_late_stage_base_cost * pow(_data.click_upgrade_cost_growth, current_level - _data.early_click_upgrade_costs.size() - 1))
	return round_to_nearest_five(_data.click_upgrade_base_cost * pow(_data.click_upgrade_cost_growth, current_level - 1))

func get_click_upgrade_max_level() -> int:
	return _data.click_upgrade_max_level

func get_critical_chance(level: int) -> float:
	return clampf(level * _data.critical_chance_per_level, 0.0, 1.0)

func get_critical_chance_upgrade_cost(current_level: int) -> int:
	return round_to_nearest_five(_data.critical_chance_base_cost * pow(_data.critical_chance_cost_growth, current_level))

func get_critical_chance_max_level() -> int:
	return _data.critical_chance_max_level

func get_critical_damage_multiplier(level: int) -> float:
	return _data.critical_damage_base_multiplier + level * _data.critical_damage_bonus_per_level

func get_critical_damage_upgrade_cost(current_level: int) -> int:
	return round_to_nearest_five(_data.critical_damage_base_cost * pow(_data.critical_damage_cost_growth, current_level))

func get_critical_damage_max_level() -> int:
	return _data.critical_damage_max_level

func get_combo_multiplier(stacks: int) -> float:
	return 1.0 + maxf(0.0, float(stacks - 1) * _data.combo_bonus_per_stack)

func get_combo_max_stacks() -> int:
	return _data.combo_max_stacks

func get_combo_timeout_seconds() -> float:
	return _data.combo_timeout_seconds

func get_equipment_level_cost(equipment_data: EquipmentData, current_level: int) -> int:
	return round_to_nearest_five(equipment_data.base_cost * pow(_data.equipment_cost_growth, current_level))

func get_equipment_dps(equipment_data: EquipmentData, level: int) -> float:
	var multiplier := 1.0
	var milestone_count := mini(equipment_data.milestone_levels.size(), equipment_data.milestone_multipliers.size())
	for index in milestone_count:
		if level >= equipment_data.milestone_levels[index]:
			multiplier *= equipment_data.milestone_multipliers[index]
	return equipment_data.base_dps * level * multiplier

func get_normal_balloon_health(balloon_data: BalloonData, variation_index: int) -> float:
	assert(balloon_data.category == BalloonData.Category.NORMAL, "Expected a normal balloon.")
	var variations := _data.normal_health_variations
	var factor := variations[variation_index % variations.size()]
	return maxf(1.0, roundf(balloon_data.base_health * factor))

func get_auto_damage_tick_interval() -> float:
	return _data.auto_damage_tick_interval

func round_to_nearest_five(value: float) -> int:
	return int(round(value / 5.0) * 5.0)

func _format_multiplier(value: float) -> String:
	return Numbers.decimal(value)
