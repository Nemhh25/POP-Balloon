class_name ContentCatalogData
extends Resource

@export var balance: GameBalanceData
@export var balloons: Array[BalloonData] = []
@export var equipment: Array[EquipmentData] = []

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

