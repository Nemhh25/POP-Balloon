class_name AttackResult
extends RefCounted

var damage: float
var was_critical: bool
var combo_multiplier: float

func _init(damage_amount: float, critical: bool = false, combo: float = 1.0) -> void:
	damage = damage_amount
	was_critical = critical
	combo_multiplier = combo

