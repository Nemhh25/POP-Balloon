class_name EquipmentData
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var base_dps: float = 0.0
@export var base_cost: int = 0
@export var max_level: int = 1
@export var required_click_damage_level: int = 1
@export var required_balloon_tier: int = 1
@export var milestone_levels := PackedInt32Array([10, 25])
@export var milestone_multipliers := PackedFloat32Array([2.0, 2.0])
