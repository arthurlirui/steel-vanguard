extends Node
## AudioManager — autoload singleton for SFX and BGM playback.
##
## Audio assets are not yet present in the project. Stream slots are stored as
# null placeholders; play_sfx/play_bgm silently no-op when a slot is null.
# To add a sound, drop the file under assets/audio/ and assign it in
# _build_stream_table() (or wire it via the inspector on this autoload's scene).

# ============================================================
# Signals
# ============================================================

signal bgm_changed(track_name: String)

# ============================================================
# SFX keys
# ============================================================

# Keep these in sync with assets/audio/README.md
const SFX_PLAYER_SHOOT := &"player_shoot"
const SFX_PLAYER_GRENADE := &"player_grenade"
const SFX_PLAYER_MELEE := &"player_melee"
const SFX_PLAYER_JUMP := &"player_jump"
const SFX_PLAYER_HURT := &"player_hurt"
const SFX_PLAYER_DIE := &"player_die"
const SFX_PLAYER_VEHICLE_IN := &"player_vehicle_in"
const SFX_PLAYER_VEHICLE_OUT := &"player_vehicle_out"

const SFX_ENEMY_SHOOT := &"enemy_shoot"
const SFX_ENEMY_HURT := &"enemy_hurt"
const SFX_ENEMY_DIE := &"enemy_die"
const SFX_ENEMY_HOP := &"enemy_hop"  # BUG variant leap cue (distinct from shooting)

const SFX_TANK_CANNON := &"tank_cannon"
const SFX_TANK_HIT := &"tank_hit"
const SFX_TANK_EXPLODE := &"tank_explode"

const SFX_EXPLOSION := &"explosion"
const SFX_PICKUP := &"pickup"
const SFX_POW_RESCUE := &"pow_rescue"
const SFX_UI_CLICK := &"ui_click"
const SFX_PAUSE := &"pause"
const SFX_GAME_OVER := &"game_over"
const SFX_VICTORY := &"victory"

# ============================================================
# State
# ============================================================

var _sfx_streams: Dictionary = {}      # StringName -> AudioStream
var _bgm_streams: Dictionary = {}      # StringName -> AudioStream
var _sfx_players: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer = null
var _sfx_volume_db: float = 0.0
var _bgm_volume_db: float = -6.0
var _muted: bool = false
const _SFX_POOL_SIZE: int = 6

# ============================================================
# Lifecycle
# ============================================================

func _ready() -> void:
	_build_stream_table()
	_create_players()

func _build_stream_table() -> void:
	# Placeholders — populate paths as assets are added.
	# Example when assets exist:
	#   _sfx_streams[SFX_PLAYER_SHOOT] = load("res://assets/audio/sfx/player_shoot.wav")
	for key in [
		SFX_PLAYER_SHOOT, SFX_PLAYER_GRENADE, SFX_PLAYER_MELEE,
		SFX_PLAYER_JUMP, SFX_PLAYER_HURT, SFX_PLAYER_DIE,
		SFX_PLAYER_VEHICLE_IN, SFX_PLAYER_VEHICLE_OUT,
		SFX_ENEMY_SHOOT, SFX_ENEMY_HURT, SFX_ENEMY_DIE, SFX_ENEMY_HOP,
		SFX_TANK_CANNON, SFX_TANK_HIT, SFX_TANK_EXPLODE,
		SFX_EXPLOSION, SFX_PICKUP, SFX_POW_RESCUE,
		SFX_UI_CLICK, SFX_PAUSE, SFX_GAME_OVER, SFX_VICTORY,
	]:
		_sfx_streams[key] = null

func _create_players() -> void:
	for i in _SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = _sfx_volume_db
		add_child(p)
		_sfx_players.append(p)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = _bgm_volume_db
	add_child(_bgm_player)

# ============================================================
# Public API
# ============================================================

func play_sfx(key: StringName) -> void:
	if _muted:
		return
	var stream: AudioStream = _sfx_streams.get(key)
	if stream == null:
		return
	var p := _grab_idle_player()
	if p:
		p.stream = stream
		p.play()

func play_bgm(track: StringName) -> void:
	if _muted:
		return
	var stream: AudioStream = _bgm_streams.get(track)
	if stream == null:
		return
	if _bgm_player.stream == stream and _bgm_player.playing:
		return
	_bgm_player.stream = stream
	_bgm_player.play()
	bgm_changed.emit(String(track))

func stop_bgm() -> void:
	_bgm_player.stop()

func set_muted(muted: bool) -> void:
	_muted = muted
	for p in _sfx_players:
		p.stream_paused = muted
	_bgm_player.stream_paused = muted

func is_muted() -> bool:
	return _muted

# ============================================================
# Internal
# ============================================================

func _grab_idle_player() -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			return p
	# All busy — reuse the first one (newest sound wins on a saturated pool)
	return _sfx_players[0]
