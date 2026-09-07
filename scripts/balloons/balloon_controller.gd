class_name BalloonController
extends Node

signal balloon_damaged(current_health: float, max_health: float, attack_result: AttackResult)
signal balloon_popped(balloon_data: BalloonData)
signal balloon_clicked

var _catalog: ContentCatalogData
var _state: GameState
var _balance: BalanceService
var _balloon_scene: PackedScene
var _container: Control
var _current_balloon: Balloon

func setup(catalog: ContentCatalogData, state: GameState, balance: BalanceService, balloon_scene: PackedScene, container: Control) -> void:
	_catalog = catalog
	_state = state
	_balance = balance
	_balloon_scene = balloon_scene
	_container = container

func spawn_current_normal(reset_health: bool = false) -> void:
	assert(_catalog != null and _balloon_scene != null and _container != null, "BalloonController must be configured before spawning.")
	var balloon_data := _catalog.find_balloon(_state.current_balloon_id)
	if balloon_data == null:
		push_error("Missing BalloonData for %s." % _state.current_balloon_id)
		return
	var max_health := _balance.get_normal_balloon_health(balloon_data, _state.normal_variation_index)
	var health := _state.current_balloon_health
	if reset_health or health <= 0.0:
		health = max_health
		_state.current_balloon_health = health
	_spawn(balloon_data, health, max_health)

func damage_current_balloon(attack_result: AttackResult) -> void:
	if is_instance_valid(_current_balloon):
		_current_balloon.take_damage(attack_result)

func get_current_health() -> float:
	return _state.current_balloon_health

func get_current_max_health() -> float:
	var balloon_data := _catalog.find_balloon(_state.current_balloon_id)
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
	_current_balloon.damaged.connect(_on_balloon_damaged)
	_current_balloon.popped.connect(_on_balloon_popped)

func _on_balloon_clicked() -> void:
	balloon_clicked.emit()

func _on_balloon_damaged(current_health: float, max_health: float, attack_result: AttackResult) -> void:
	_state.current_balloon_health = current_health
	balloon_damaged.emit(current_health, max_health, attack_result)

func _on_balloon_popped(balloon_data: BalloonData) -> void:
	balloon_popped.emit(balloon_data)
	get_tree().create_timer(0.13).timeout.connect(_spawn_after_pop, CONNECT_ONE_SHOT)

func _spawn_after_pop() -> void:
	_state.current_balloon_health = 0.0
	_state.normal_variation_index += 1
	spawn_current_normal(true)
