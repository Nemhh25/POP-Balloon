class_name BuffService
extends Node

const Numbers = preload("res://scripts/ui/number_format.gd")

signal buffs_changed(active_text: String)

const ELECTRIC_ID := &"electric"
const FRENZY_ID := &"frenzy"

var _active: Dictionary = {}
var _expiry_timer: Timer

func _ready() -> void:
	_expiry_timer = Timer.new()
	_expiry_timer.one_shot = true
	_expiry_timer.timeout.connect(_expire_due_buffs)
	add_child(_expiry_timer)

func activate(id: StringName, multiplier: float, duration_seconds: float) -> void:
	_active[id] = {"multiplier": multiplier, "expires_at": Time.get_ticks_msec() + roundi(duration_seconds * 1000.0)}
	_schedule_expiry()
	buffs_changed.emit(get_active_text())

func get_multiplier(id: StringName) -> float:
	_expire_due_buffs()
	return float((_active.get(id, {}) as Dictionary).get("multiplier", 1.0))

func get_active_text() -> String:
	_expire_due_buffs()
	if _active.is_empty():
		return ""
	var parts: Array[String] = []
	var now := Time.get_ticks_msec()
	for id: StringName in _active:
		var entry: Dictionary = _active[id]
		var seconds := maxf(0.0, (float(entry["expires_at"]) - now) / 1000.0)
		parts.append("%s ×%s (%ds)" % [String(id).capitalize(), _format_multiplier(float(entry["multiplier"])), ceili(seconds)])
	return "BUFF: %s" % " · ".join(parts)

func _expire_due_buffs() -> void:
	var now := Time.get_ticks_msec()
	var changed := false
	for id: Variant in _active.keys():
		if int((_active[id] as Dictionary)["expires_at"]) <= now:
			_active.erase(id)
			changed = true
	_schedule_expiry()
	if changed:
		buffs_changed.emit(get_active_text())

func _schedule_expiry() -> void:
	if _expiry_timer == null:
		return
	if _active.is_empty():
		_expiry_timer.stop()
		return
	var earliest := 9223372036854775807
	for entry: Dictionary in _active.values():
		earliest = mini(earliest, int(entry["expires_at"]))
	_expiry_timer.start(maxf(0.05, (earliest - Time.get_ticks_msec()) / 1000.0))

func _format_multiplier(value: float) -> String:
	return Numbers.decimal(value)
