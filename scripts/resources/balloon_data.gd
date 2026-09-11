class_name BalloonData
extends Resource

enum Category {
	NORMAL,
	SPECIAL,
	BOSS,
}

enum SpecialEffect {
	NONE,
	GOLDEN_COINS,
	CRYSTAL_DIAMONDS,
	ELECTRIC_AUTODPS,
	FRENZY_CLICK,
}

@export var id: StringName
@export var display_name: String
@export var category: Category = Category.NORMAL
@export var tier_index: int = 0
@export var base_health: float = 1.0
@export var coin_reward: int = 0
@export var diamond_reward: int = 0
@export var display_color: Color = Color.WHITE
@export var unlock_pop_requirement: int = 0
@export var unlock_coin_requirement: int = 0
@export var unlock_required_equipment_id: StringName
@export var unlock_required_equipment_level: int = 0
@export var special_effect: SpecialEffect = SpecialEffect.NONE
