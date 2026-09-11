class_name SpecialBalloonScheduler
extends Node

signal special_started(balloon_data: BalloonData)
signal special_expired(balloon_data: BalloonData)

const GOLDEN_SPECIAL_ID := &"golden_special_balloon"
const DIAMOND_EVENT_ID := &"crystal_balloon"
const GOLDEN_SPECIAL_POP_INTERVAL := 5

var _catalog: ContentCatalogData
var _reveal_service: RevealService
var _balance: GameBalanceData
var _duration_timer: Timer
var _diamond_event_timer: Timer
var _active: BalloonData
var _state: GameState
var _diamond_event_pending := false
var _buff_event_pending := false
var _last_buff_event_id: StringName = &""
var _random := RandomNumberGenerator.new()

func setup(catalog: ContentCatalogData, reveal_service: RevealService, state: GameState) -> void:
	_catalog = catalog
	_reveal_service = reveal_service
	_state = state
	_balance = catalog.balance
	_duration_timer = Timer.new()
	_duration_timer.one_shot = true
	_duration_timer.timeout.connect(_expire_active_special)
	add_child(_duration_timer)
	_diamond_event_timer = Timer.new()
	_diamond_event_timer.timeout.connect(_try_start_diamond_event)
	add_child(_diamond_event_timer)
	refresh_special_frequency()
	refresh_diamond_event_frequency()
	_diamond_event_timer.start()

func refresh_special_frequency() -> void:
	# Frequency is evaluated from the current upgrade level on each normal pop.
	# Keeping this entry point lets the session refresh its presentation without a
	# second timing system for Electric/Frenzy.
	pass

func get_buff_event_pop_interval() -> int:
	var multiplier := 1.0
	for data: GlobalUpgradeData in _catalog.global_upgrades:
		if data.effect == GlobalUpgradeData.Effect.SPECIAL_FREQUENCY:
			multiplier += _state.get_global_upgrade_level(data.id) * data.bonus_per_level
	return maxi(1, ceili(float(_balance.buff_special_pop_interval) / multiplier))

func refresh_diamond_event_frequency() -> void:
	if _diamond_event_timer == null or _state == null:
		return
	var reduction := _state.diamond_event_frequency_level * _balance.diamond_event_frequency_reduction_per_level
	_diamond_event_timer.wait_time = _balance.diamond_event_base_interval_seconds * maxf(0.5, 1.0 - reduction)
	if not _diamond_event_timer.is_stopped():
		_diamond_event_timer.start()

func complete_active_special() -> void:
	if _active == null:
		return
	_duration_timer.stop()
	_active = null
	_start_pending_special.call_deferred()

func has_active_special() -> bool:
	return _active != null

func notify_normal_balloon_popped(total_normal_pops: int) -> void:
	if total_normal_pops <= 0:
		return
	# A buff threshold can coincide with Golden (45 is also divisible by 5).
	# Give Electric/Frenzy priority so the player sees the requested event on the
	# exact pop milestone instead of only after a Golden Balloon resolves.
	if total_normal_pops % get_buff_event_pop_interval() == 0:
		_try_start_buff_event()
	if total_normal_pops % GOLDEN_SPECIAL_POP_INTERVAL == 0:
		_try_start_golden_special()

func _try_start_golden_special() -> void:
	if _active != null or not _reveal_service.is_revealed(GOLDEN_SPECIAL_ID):
		return
	var golden_special := _catalog.find_balloon(GOLDEN_SPECIAL_ID)
	if golden_special == null:
		push_error("Missing Golden Special Balloon data.")
		return
	_active = golden_special
	special_started.emit(_active)
	_duration_timer.start(_balance.special_active_duration_seconds)

func _try_start_buff_event() -> void:
	if _active != null:
		_buff_event_pending = true
		return
	var candidates: Array[BalloonData] = []
	for balloon_data: BalloonData in _catalog.balloons:
		if balloon_data.category == BalloonData.Category.SPECIAL and balloon_data.id not in [GOLDEN_SPECIAL_ID, DIAMOND_EVENT_ID] and _reveal_service.is_revealed(balloon_data.id):
			candidates.append(balloon_data)
	if candidates.is_empty():
		return
	var eligible := candidates
	if candidates.size() > 1:
		eligible = candidates.filter(func(balloon: BalloonData) -> bool: return balloon.id != _last_buff_event_id)
	_active = eligible[_random.randi_range(0, eligible.size() - 1)]
	_last_buff_event_id = _active.id
	_buff_event_pending = false
	special_started.emit(_active)
	_duration_timer.start(_balance.special_active_duration_seconds)

func _try_start_diamond_event() -> void:
	if not _reveal_service.is_revealed(DIAMOND_EVENT_ID):
		return
	if _active != null:
		# A Crystal event due during another special must wait, not vanish for an
		# entire timer cycle. This prevents frequent Golden Specials from starving
		# the Diamond economy.
		_diamond_event_pending = true
		return
	var diamond_event := _catalog.find_balloon(DIAMOND_EVENT_ID)
	if diamond_event == null:
		push_error("Missing Crystal Balloon data.")
		return
	_diamond_event_pending = false
	_active = diamond_event
	special_started.emit(_active)
	_duration_timer.start(_balance.special_active_duration_seconds)

func _start_pending_special() -> void:
	if _active != null:
		return
	if _diamond_event_pending:
		_try_start_diamond_event()
	if _active == null and _buff_event_pending:
		_try_start_buff_event()

func _expire_active_special() -> void:
	if _active == null:
		return
	var expired := _active
	_active = null
	special_expired.emit(expired)
	_start_pending_special.call_deferred()
