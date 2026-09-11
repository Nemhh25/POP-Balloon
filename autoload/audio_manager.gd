class_name PopAudioManager
extends Node

# Centralized audio mix. Utility feedback streams are generated locally while
# final licensed assets can replace the cache without touching gameplay calls.
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"
const SAMPLE_RATE := 11025
const MENU_THEME_PATH := "res://assets/audio/music/menu_theme.ogg"
const GAMEPLAY_THEME_PATH := "res://assets/audio/music/gameplay_theme.ogg"
const BOSS_THEME_PATH := "res://assets/audio/music/balloon_king_theme.ogg"
const POP_VARIATION_PATHS := [
	"res://assets/audio/sfx/balloon_pop_01.ogg",
	"res://assets/audio/sfx/balloon_pop_02.ogg",
	"res://assets/audio/sfx/balloon_pop_03.ogg",
]
const POP_VARIATION_IDS := [&"balloon_pop_01", &"balloon_pop_02", &"balloon_pop_03"]
const MUSIC_TRANSITION_SECONDS := 0.55

var _random := RandomNumberGenerator.new()
var _streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _music_players: Array[AudioStreamPlayer] = []
var _music_index := 0
var _last_played: Dictionary = {}
var _music_state := &""
var _menu_theme: AudioStreamOggVorbis
var _gameplay_theme: AudioStreamOggVorbis
var _boss_theme: AudioStreamOggVorbis
var _pop_variations: Array[AudioStreamOggVorbis] = []

func _ready() -> void:
	_ensure_buses()
	for _index in 6:
		_sfx_players.append(_make_player(BUS_SFX))
	for _index in 3:
		_ui_players.append(_make_player(BUS_UI))
	for _index in 2:
		_music_players.append(_make_player(BUS_MUSIC))
	_menu_theme = load(MENU_THEME_PATH) as AudioStreamOggVorbis
	_gameplay_theme = load(GAMEPLAY_THEME_PATH) as AudioStreamOggVorbis
	_boss_theme = load(BOSS_THEME_PATH) as AudioStreamOggVorbis
	for path: String in POP_VARIATION_PATHS:
		var stream := load(path) as AudioStreamOggVorbis
		assert(stream != null, "POP Balloon pop SFX must be imported.")
		_pop_variations.append(stream)
	assert(_menu_theme != null and _gameplay_theme != null and _boss_theme != null, "POP Balloon music themes must be imported.")
	_menu_theme.loop = true
	_gameplay_theme.loop = true
	_boss_theme.loop = true
	_streams = _build_streams()


func _exit_tree() -> void:
	# AudioStreamPlayer can retain an active playback until the audio thread
	# advances. Stopping them explicitly keeps shutdown and test runs clean.
	for player in _sfx_players + _ui_players + _music_players:
		if is_instance_valid(player):
			player.stop()
	_streams.clear()

func apply_settings(master: float, music: float, sfx: float) -> void:
	_set_bus_volume(&"Master", master)
	_set_bus_volume(BUS_MUSIC, music)
	_set_bus_volume(BUS_SFX, sfx)
	_set_bus_volume(BUS_UI, sfx)

func play_manual_hit() -> void:
	_play(&"hit", 0.94, 1.06, 0.035, true)

func play_critical() -> void:
	_play(&"critical", 0.98, 1.03, 0.0)

func play_pop(is_special: bool = false) -> StringName:
	if is_special:
		_play(&"special_pop", 0.95, 1.05, 0.075)
		return &"special_pop"
	var variation: StringName = POP_VARIATION_IDS[_random.randi_range(0, POP_VARIATION_IDS.size() - 1)]
	_play(variation, 0.96, 1.04, 0.045, true)
	return variation

func play_diamond() -> void:
	_play(&"diamond", 1.0, 1.0, 0.15)

func play_purchase(milestone: bool = false) -> void:
	_play_ui(&"milestone" if milestone else &"purchase", 0.98, 1.03, 0.055)

func play_reveal() -> void:
	_play_ui(&"reveal", 1.0, 1.0, 0.12)

func play_unlock() -> void:
	_play(&"unlock", 1.0, 1.0, 0.2)

func play_special_spawn(kind: StringName) -> void:
	_play(&"crystal" if kind == &"crystal_balloon" else &"special", 0.98, 1.02, 0.2)

func play_buff() -> void:
	_play(&"buff", 0.98, 1.02, 0.15)

func play_toggle(enabled: bool) -> void:
	_play_ui(&"toggle_on" if enabled else &"toggle_off", 1.0, 1.0, 0.08)

func play_tab() -> void:
	_play_ui(&"tab", 1.0, 1.0, 0.05)

func play_menu_music() -> void:
	play_music(&"menu", MUSIC_TRANSITION_SECONDS)

func play_gameplay_music() -> void:
	play_music(&"gameplay", MUSIC_TRANSITION_SECONDS)

func play_menu_confirm() -> void:
	_play_ui(&"purchase", 1.0, 1.0, 0.08)

func play_menu_cancel() -> void:
	_play_ui(&"toggle_off", 1.0, 1.0, 0.08)

func start_boss_music() -> void:
	_play(&"boss_intro", 1.0, 1.0, 0.25)
	play_music(&"boss", MUSIC_TRANSITION_SECONDS)

func play_boss_phase() -> void:
	_play(&"boss_phase", 1.0, 1.0, 0.25)

func play_boss_victory() -> void:
	_play(&"boss_pop", 1.0, 1.0, 0.0)
	play_music(&"victory", 0.5)

func play_music(state: StringName, fade_seconds: float = 0.35) -> void:
	if _music_state == state or not _streams.has(state):
		return
	_music_state = state
	var incoming := _music_players[_music_index]
	var outgoing := _music_players[1 - _music_index]
	_music_index = 1 - _music_index
	incoming.stream = _streams[state]
	incoming.volume_db = -60.0 if fade_seconds > 0.0 else -10.0
	incoming.play()
	if fade_seconds <= 0.0:
		outgoing.stop()
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(incoming, "volume_db", -10.0, fade_seconds)
	if outgoing.playing:
		tween.tween_property(outgoing, "volume_db", -60.0, fade_seconds)
		tween.chain().tween_callback(outgoing.stop)

func _stop_music(fade_seconds: float) -> void:
	_music_state = &""
	for player in _music_players:
		if not player.playing:
			continue
		if fade_seconds <= 0.0:
			player.stop()
		else:
			var tween := create_tween()
			tween.tween_property(player, "volume_db", -60.0, fade_seconds)
			tween.tween_callback(player.stop)

func _play(id: StringName, low_pitch: float, high_pitch: float, cooldown: float, randomize: bool = false) -> void:
	_play_from(_sfx_players, id, low_pitch, high_pitch, cooldown, randomize)

func _play_ui(id: StringName, low_pitch: float, high_pitch: float, cooldown: float) -> void:
	_play_from(_ui_players, id, low_pitch, high_pitch, cooldown, false)

func _play_from(players: Array[AudioStreamPlayer], id: StringName, low_pitch: float, high_pitch: float, cooldown: float, randomize: bool) -> void:
	if not _streams.has(id):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(id, -999.0)) < cooldown:
		return
	_last_played[id] = now
	var player := _available_player(players)
	if player == null:
		return
	player.stream = _streams[id]
	player.pitch_scale = _random.randf_range(low_pitch, high_pitch) if randomize else low_pitch
	player.play()

func _available_player(players: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	for player in players:
		if not player.playing:
			return player
	return null

func _make_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player

func _ensure_buses() -> void:
	for bus in [BUS_MUSIC, BUS_SFX, BUS_UI]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)

func _set_bus_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, clampf(linear, 0.0, 1.0))))

func _build_streams() -> Dictionary:
	return {
		&"hit": _tone([Vector3(620, 0.035, 0.24)], 0.06, 0.2),
		&"critical": _tone([Vector3(750, 0.06, 0.42), Vector3(1140, 0.08, 0.25)], 0.15, 0.5),
		&"balloon_pop_01": _pop_variations[0],
		&"balloon_pop_02": _pop_variations[1],
		&"balloon_pop_03": _pop_variations[2],
		&"special_pop": _tone([Vector3(240, 0.1, 0.5), Vector3(700, 0.13, 0.32)], 0.22, 0.55),
		&"diamond": _tone([Vector3(1040, 0.12, 0.28), Vector3(1560, 0.16, 0.2)], 0.36, 0.35),
		&"purchase": _tone([Vector3(520, 0.06, 0.28), Vector3(740, 0.09, 0.24)], 0.16, 0.2),
		&"milestone": _tone([Vector3(520, 0.07, 0.3), Vector3(780, 0.1, 0.28), Vector3(1040, 0.13, 0.23)], 0.28, 0.3),
		&"reveal": _tone([Vector3(660, 0.08, 0.25), Vector3(930, 0.12, 0.22)], 0.24, 0.3),
		&"unlock": _tone([Vector3(390, 0.1, 0.3), Vector3(585, 0.14, 0.26), Vector3(780, 0.18, 0.22)], 0.38, 0.3),
		&"special": _tone([Vector3(700, 0.1, 0.25), Vector3(930, 0.13, 0.22)], 0.28, 0.4),
		&"crystal": _tone([Vector3(880, 0.1, 0.25), Vector3(1320, 0.15, 0.22)], 0.35, 0.4),
		&"buff": _tone([Vector3(460, 0.08, 0.25), Vector3(920, 0.15, 0.2)], 0.3, 0.25),
		&"toggle_on": _tone([Vector3(680, 0.08, 0.22)], 0.12, 0.2),
		&"toggle_off": _tone([Vector3(370, 0.08, 0.2)], 0.12, 0.2),
		&"tab": _tone([Vector3(540, 0.055, 0.2)], 0.09, 0.18),
		&"boss_intro": _tone([Vector3(170, 0.14, 0.45), Vector3(235, 0.24, 0.35)], 0.45, 0.45),
		&"boss_phase": _tone([Vector3(240, 0.12, 0.35), Vector3(420, 0.18, 0.28)], 0.34, 0.4),
		&"boss_pop": _tone([Vector3(110, 0.15, 0.65), Vector3(440, 0.2, 0.35), Vector3(880, 0.28, 0.2)], 0.6, 0.55),
		&"menu": _menu_theme,
		&"gameplay": _gameplay_theme,
		&"boss": _boss_theme,
		&"victory": _music([392.0, 493.9, 587.3, 783.9], 0.2),
	}

func _tone(notes: Array[Vector3], duration: float, square_mix: float) -> AudioStreamWAV:
	var frames := maxi(1, roundi(duration * SAMPLE_RATE))
	var samples := PackedByteArray()
	samples.resize(frames * 2)
	for frame in frames:
		var time := float(frame) / SAMPLE_RATE
		var value := 0.0
		for note in notes:
			var local_time := time - note.y
			if local_time >= 0.0:
				var envelope := exp(-local_time * 16.0) * (1.0 - exp(-local_time * 80.0))
				var phase := TAU * note.x * local_time
				value += (sin(phase) * (1.0 - square_mix) + sign(sin(phase)) * square_mix) * note.z * envelope
		samples.encode_s16(frame * 2, clampi(roundi(value * 26000.0), -32767, 32767))
	return _wav(samples)

func _music(notes: Array[float], gain: float) -> AudioStreamWAV:
	var length := 2.4
	var frames := roundi(length * SAMPLE_RATE)
	var samples := PackedByteArray()
	samples.resize(frames * 2)
	for frame in frames:
		var time := float(frame) / SAMPLE_RATE
		var step := int(time / 0.3) % notes.size()
		var phase_time := fmod(time, 0.3)
		var envelope := 0.32 + exp(-phase_time * 7.0) * 0.68
		var root := notes[step]
		var value := (sin(TAU * root * time) * 0.48 + sin(TAU * root * 2.0 * time) * 0.16 + sin(TAU * root * 0.5 * time) * 0.24) * gain * envelope
		samples.encode_s16(frame * 2, clampi(roundi(value * 21000.0), -32767, 32767))
	var stream := _wav(samples)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = frames
	return stream

func _wav(samples: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = samples
	return stream
