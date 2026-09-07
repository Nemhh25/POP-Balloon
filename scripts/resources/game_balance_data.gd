class_name GameBalanceData
extends Resource

@export_category("Click Damage")
@export var click_damage_base: float = 1.0
@export var click_damage_growth: float = 1.155
@export var click_upgrade_base_cost: float = 10.0
@export var click_upgrade_cost_growth: float = 1.24
@export var click_upgrade_max_level: int = 45

@export_category("Equipment")
@export var equipment_cost_growth: float = 1.12
@export var auto_damage_tick_interval: float = 0.25

@export_category("Balloon")
@export var normal_health_variations := PackedFloat32Array([0.95, 0.98, 1.0, 1.02, 1.05])

