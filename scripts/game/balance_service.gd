class_name BalanceService
extends RefCounted

var _data: GameBalanceData

func _init(data: GameBalanceData) -> void:
	assert(data != null, "GameBalanceData is required.")
	_data = data

func get_click_damage(level: int) -> float:
	return float(round(_data.click_damage_base * pow(_data.click_damage_growth, level - 1)))

func get_click_upgrade_cost(current_level: int) -> int:
	return round_to_nearest_five(_data.click_upgrade_base_cost * pow(_data.click_upgrade_cost_growth, current_level - 1))

func get_click_upgrade_max_level() -> int:
	return _data.click_upgrade_max_level

func get_equipment_level_cost(equipment_data: EquipmentData, current_level: int) -> int:
	return round_to_nearest_five(equipment_data.base_cost * pow(_data.equipment_cost_growth, current_level))

func get_equipment_dps(equipment_data: EquipmentData, level: int) -> float:
	return equipment_data.base_dps * level

func get_normal_balloon_health(balloon_data: BalloonData, variation_index: int) -> float:
	assert(balloon_data.category == BalloonData.Category.NORMAL, "Expected a normal balloon.")
	var variations := _data.normal_health_variations
	var factor := variations[variation_index % variations.size()]
	return maxf(1.0, roundf(balloon_data.base_health * factor))

func get_auto_damage_tick_interval() -> float:
	return _data.auto_damage_tick_interval

func round_to_nearest_five(value: float) -> int:
	return int(round(value / 5.0) * 5.0)
