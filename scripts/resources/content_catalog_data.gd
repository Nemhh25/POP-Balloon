class_name ContentCatalogData
extends Resource

@export var balance: GameBalanceData
@export var balloons: Array[BalloonData] = []
@export var equipment: Array[EquipmentData] = []
@export var reveal_rules: Array[RevealRuleData] = []
@export var global_upgrades: Array[GlobalUpgradeData] = []

func find_balloon(id: StringName) -> BalloonData:
	for balloon: BalloonData in balloons:
		if balloon.id == id:
			return balloon
	return null

func find_equipment(id: StringName) -> EquipmentData:
	for equipment_data: EquipmentData in equipment:
		if equipment_data.id == id:
			return equipment_data
	return null

func find_reveal_rule(id: StringName) -> RevealRuleData:
	for rule: RevealRuleData in reveal_rules:
		if rule.id == id:
			return rule
	return null

func find_global_upgrade(id: StringName) -> GlobalUpgradeData:
	for upgrade: GlobalUpgradeData in global_upgrades:
		if upgrade.id == id:
			return upgrade
	return null
