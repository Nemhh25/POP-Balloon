class_name BalloonController
extends Node

signal balloon_damaged(current_health: float, max_health: float, attack_result: AttackResult)
signal balloon_popped(balloon_data: BalloonData)
signal special_balloon_popped(balloon_data: BalloonData)
signal boss_balloon_popped(balloon_data: BalloonData)
signal balloon_clicked
signal balloon_hold_started
signal balloon_hold_ended

const POP_RESPAWN_DELAY_SECONDS := 0.13

var _catalog: ContentCatalogData
var _state: GameState
var _balance: BalanceService
var _balloon_scene: PackedScene
var _container: Control
var _current_balloon: Balloon
var _active_special: BalloonData
var _active_boss: BalloonData

func setup(catalog: ContentCatalogData, state: GameState, balance: BalanceService, balloon_scene: PackedScene, container: Control) -> void:
	_catalog = catalog
	_state = state
	_balance = balance
	_balloon_scene = balloon_scene
	_container = container

func spawn_current_normal(reset_health: bool = false) -> void:
	assert(_catalog != null and _balloon_scene != null and _container != null, "BalloonController must be configured before spawning.")
	var balloon_data := _catalog.find_balloon(_state.current_normal_balloon_id)
	if balloon_data == null:
		push_error("Missing BalloonData for %s." % _state.current_normal_balloon_id)
		return
	var max_health := _balance.get_normal_balloon_health(balloon_data, _state.normal_variation_index)
	var health := _state.current_balloon_health
	if reset_health or health <= 0.0:
		health = max_health
		_state.current_balloon_health = health
	if _active_special == null:
		_spawn(balloon_data, health, max_health)

func set_current_normal_balloon(id: StringName) -> void:
	if _catalog.find_balloon(id) == null:
		push_error("Cannot select unknown BalloonData: %s." % id)
		return
	_state.current_normal_balloon_id = id
	_state.current_balloon_health = 0.0
	spawn_current_normal(true)

func damage_current_balloon(attack_result: AttackResult) -> void:
	if is_instance_valid(_current_balloon):
		_current_balloon.take_damage(attack_result)

func start_boss(balloon_data: BalloonData) -> void:
	if balloon_data == null or balloon_data.category != BalloonData.Category.BOSS:
		return
	_active_boss = balloon_data
	var health := _state.boss_health if _state.boss_health > 0.0 else balloon_data.base_health
	_state.boss_health = health
	_spawn(balloon_data, health, balloon_data.base_health)

func is_boss_active() -> bool:
	return _active_boss != null

func start_special(balloon_data: BalloonData) -> void:
	if balloon_data == null or balloon_data.category != BalloonData.Category.SPECIAL or _active_special != null:
		return
	_active_special = balloon_data
	var special_health := balloon_data.base_health
	if balloon_data.special_effect == BalloonData.SpecialEffect.GOLDEN_COINS:
		var current_normal := _catalog.find_balloon(_state.current_normal_balloon_id)
		if current_normal != null:
			special_health = _balance.get_normal_balloon_health(current_normal, _state.normal_variation_index)
	_spawn(balloon_data, special_health, special_health)

func end_special() -> void:
	if _active_special == null and _active_boss == null:
		return
	_active_special = null
	spawn_current_normal()

func end_boss() -> void:
	if _active_boss == null:
		return
	_active_boss = null
	spawn_current_normal()

func get_current_health() -> float:
	return _current_balloon.get_current_health() if is_instance_valid(_current_balloon) else _state.current_balloon_health

func get_current_max_health() -> float:
	var balloon_data := _catalog.find_balloon(_state.current_normal_balloon_id)
	if balloon_data == null:
		return 1.0
	return _balance.get_normal_balloon_health(balloon_data, _state.normal_variation_index)

func _spawn(balloon_data: BalloonData, health: float, max_health: float) -> void:
	if is_instance_valid(_current_balloon):
		_current_balloon.queue_free()
	_current_balloon = _balloon_scene.instantiate() as Balloon
	_container.add_child(_current_balloon)
	_current_balloon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_current_balloon.configure(balloon_data, health, max_health)
	_current_balloon.clicked.connect(_on_balloon_clicked)
	_current_balloon.hold_started.connect(func() -> void: balloon_hold_started.emit())
	_current_balloon.hold_ended.connect(func() -> void: balloon_hold_ended.emit())
	_current_balloon.damaged.connect(_on_balloon_damaged)
	_current_balloon.popped.connect(_on_balloon_popped)

func _on_balloon_clicked() -> void:
	balloon_clicked.emit()

func _on_balloon_damaged(current_health: float, max_health: float, attack_result: AttackResult) -> void:
	if _active_boss != null:
		_state.boss_health = current_health
	elif _active_special == null:
		_state.current_balloon_health = current_health
	balloon_damaged.emit(current_health, max_health, attack_result)

func _on_balloon_popped(balloon_data: BalloonData) -> void:
	if balloon_data.category == BalloonData.Category.SPECIAL:
		special_balloon_popped.emit(balloon_data)
		return
	if balloon_data.category == BalloonData.Category.BOSS:
		boss_balloon_popped.emit(balloon_data)
		return
	balloon_popped.emit(balloon_data)
	get_tree().create_timer(POP_RESPAWN_DELAY_SECONDS).timeout.connect(_spawn_after_pop, CONNECT_ONE_SHOT)

func _spawn_after_pop() -> void:
	_state.current_balloon_health = 0.0
	_state.normal_variation_index += 1
	spawn_current_normal(true)
