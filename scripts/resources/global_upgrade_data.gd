class_name GlobalUpgradeData
extends Resource

enum Effect {
	AUTO_DPS,
	COIN_GAIN,
	CLICK_DAMAGE,
	CRITICAL_DAMAGE,
	BUFF_DURATION,
	BUFF_POWER,
	SPECIAL_FREQUENCY,
	COMBO_POWER,
}

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var effect: Effect = Effect.AUTO_DPS
@export var base_diamond_cost: int = 1
@export var max_level: int = 5
@export var bonus_per_level: float = 0.1
@export var required_tier: int = 1
@export var requires_buff_discovery: bool = false
@export var legacy_only: bool = false

# Shared, moderate Diamond curve; the existing event-frequency upgrade retains
# its own established costs in GameBalanceData.
const DIAMOND_COSTS := [1, 2, 3, 5, 8, 12, 18, 25, 35, 50]

func cost_at_level(level: int) -> int:
	if legacy_only or level < 0 or level >= max_level:
		return 0
	return DIAMOND_COSTS[mini(level, DIAMOND_COSTS.size() - 1)]
