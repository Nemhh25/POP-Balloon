class_name GameBalanceData
extends Resource

@export_category("Click Damage")
@export var click_damage_base: float = 1.0
@export var click_damage_growth: float = 1.155
@export var click_damage_per_level: float = 1.0
@export var click_upgrade_base_cost: float = 10.0
@export var click_upgrade_cost_growth: float = 1.24
@export var early_click_upgrade_costs := PackedInt32Array([5, 5, 10, 10, 15, 20, 25, 30, 40, 50, 60, 75, 90, 110])
@export var click_late_stage_base_cost: float = 180.0
@export var click_upgrade_max_level: int = 0 # 0 = unlimited
@export var click_milestone_interval: int = 25
@export var click_milestone_bonus: float = 0.10

@export_category("Economy Upgrades")
@export var coin_reward_bonus_per_level: float = 0.05
@export var coin_reward_max_level: int = 10
@export var coin_reward_cost_reward_multiplier: float = 2.0
@export var coin_reward_cost_growth: float = 1.65
@export var coin_reward_minimum_cost: int = 1000
@export var diamond_reward_bonus_chance_per_level: float = 0.15
@export var diamond_reward_max_level: int = 3
@export var diamond_reward_base_cost: int = 2
@export var diamond_event_base_interval_seconds: float = 18.0
@export var diamond_event_frequency_reduction_per_level: float = 0.06
@export var diamond_event_frequency_max_level: int = 5
@export var diamond_event_frequency_costs := PackedInt32Array([2, 4, 7, 11, 16])
@export var buff_frequency_bonus_per_level: float = 0.002
@export var buff_frequency_max_level: int = 25
@export var buff_frequency_click_requirement: int = 500

@export_category("Critical Hits")
@export var critical_chance_per_level: float = 0.003
@export var critical_chance_max_level: int = 117
@export var critical_chance_base_cost: float = 100.0
@export var critical_chance_cost_growth: float = 1.35
@export var critical_damage_base_multiplier: float = 1.0
@export var critical_damage_bonus_per_level: float = 0.3
@export var critical_damage_max_level: int = 5
@export var critical_damage_base_cost: float = 250.0
@export var critical_damage_cost_growth: float = 1.42

@export_category("Combo")
@export var combo_max_stacks: int = 20
@export var combo_bonus_per_stack: float = 0.05
@export var combo_timeout_seconds: float = 1.5

@export_category("Equipment")
@export var equipment_cost_growth: float = 1.12
@export var auto_damage_tick_interval: float = 0.25

@export_category("Special Balloons")
@export var buff_special_pop_interval: int = 45
@export var special_active_duration_seconds: float = 10.0
@export var electric_auto_dps_multiplier: float = 2.0
@export var electric_buff_duration_seconds: float = 12.0
@export var frenzy_click_multiplier: float = 2.0
@export var frenzy_buff_duration_seconds: float = 12.0

@export_category("Balloon")
@export var normal_health_variations := PackedFloat32Array([0.95, 0.98, 1.0, 1.02, 1.05])
