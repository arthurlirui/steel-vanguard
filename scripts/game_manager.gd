extends Node
## GameManager — Global singleton (Autoload)
## Manages game state, score, level, lives, weapon ammo, and signals.

# ============================================================
# Signals
# ============================================================

signal state_changed(new_state: GameState)
signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
signal health_changed(new_health: int, max_health: int)
signal weapon_changed(weapon_id: int)
signal ammo_changed(weapon_id: int, ammo: int)
signal grenade_count_changed(count: int)
signal level_changed(level_num: int)
signal pow_rescued(count: int)
signal vehicle_entered()
signal vehicle_exited()
signal enemies_remaining_changed(killed: int, total: int)

# ============================================================
# Enums
# ============================================================

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER, VICTORY }

# ============================================================
# Constants
# ============================================================

const MAX_HEALTH: int = 100
const MAX_LIVES: int = 3
const START_GRENADES: int = 10
const MAX_WEAPON_AMMO: int = 999

# ============================================================
# State
# ============================================================

var current_state: GameState = GameState.MENU
var score: int = 0
var lives: int = MAX_LIVES
var current_level: int = 1
var pow_rescued_count: int = 0

# Player health (mirrored for HUD access)
var player_health: int = MAX_HEALTH

# Weapon system — ammo values mirror WeaponData.WEAPONS[*]["ammo"]
# to avoid a hard dependency on WeaponData at reset time.
var current_weapon_id: int = 0
var weapon_ammo: Dictionary = {
	0: -1,   # Pistol: infinite
	1: 200,  # HMG
	2: 50,   # Shotgun
	3: 30,   # Rocket
	4: 150,  # Flamethrower
}

var grenade_count: int = START_GRENADES

# Level kill tracking (populated by Level)
var enemies_killed: int = 0
var total_enemies: int = 0

# ============================================================
# Lifecycle
# ============================================================

func _ready() -> void:
	_reset_state()

# ============================================================
# State Management
# ============================================================

func change_state(new_state: GameState) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_changed.emit(new_state)

func start_game() -> void:
	_reset_state()
	change_state(GameState.PLAYING)

func pause_game() -> void:
	if current_state == GameState.PLAYING:
		change_state(GameState.PAUSED)
		get_tree().paused = true

func resume_game() -> void:
	if current_state == GameState.PAUSED:
		get_tree().paused = false
		change_state(GameState.PLAYING)

func game_over() -> void:
	if current_state == GameState.GAME_OVER:
		return
	change_state(GameState.GAME_OVER)
	get_tree().paused = false
	AudioManager.play_sfx(AudioManager.SFX_GAME_OVER)

func victory() -> void:
	if current_state == GameState.VICTORY:
		return
	change_state(GameState.VICTORY)
	get_tree().paused = false
	AudioManager.play_sfx(AudioManager.SFX_VICTORY)

func restart_game() -> void:
	get_tree().paused = false
	_reset_state()
	get_tree().reload_current_scene()
	change_state(GameState.PLAYING)

# ============================================================
# Score & Progression
# ============================================================

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func add_health(amount: int) -> void:
	player_health = clamp(player_health + amount, 0, MAX_HEALTH)
	health_changed.emit(player_health, MAX_HEALTH)

func player_take_damage(amount: int) -> void:
	if current_state != GameState.PLAYING:
		return
	if player_health <= 0:
		return  # Already dying this life
	player_health = max(0, player_health - amount)
	health_changed.emit(player_health, MAX_HEALTH)
	if player_health <= 0:
		_lose_life()

func _lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		game_over()
	else:
		# Reset health for next life; the Player handles its own respawn timing.
		player_health = MAX_HEALTH
		health_changed.emit(player_health, MAX_HEALTH)

func next_level() -> void:
	current_level += 1
	level_changed.emit(current_level)

func register_enemy_killed() -> void:
	enemies_killed += 1
	enemies_remaining_changed.emit(enemies_killed, total_enemies)

# ============================================================
# Weapon System
# ============================================================

func switch_weapon(weapon_id: int) -> void:
	if weapon_id < 0 or weapon_id > 4:
		return
	if weapon_ammo.get(weapon_id, 0) == 0:
		return  # Can't switch to empty weapon
	current_weapon_id = weapon_id
	weapon_changed.emit(weapon_id)

func get_current_ammo() -> int:
	return weapon_ammo.get(current_weapon_id, 0)

func consume_ammo(weapon_id: int, amount: int = 1) -> void:
	var current: int = weapon_ammo.get(weapon_id, 0)
	if current == -1:
		return  # Infinite ammo
	weapon_ammo[weapon_id] = max(0, current - amount)
	ammo_changed.emit(weapon_id, weapon_ammo[weapon_id])
	# Auto-switch to pistol if out of ammo
	if weapon_ammo[weapon_id] == 0 and current_weapon_id == weapon_id:
		switch_weapon(0)

func add_ammo(weapon_id: int, amount: int) -> void:
	var current: int = weapon_ammo.get(weapon_id, 0)
	if current == -1:
		return  # Infinite-ammo weapon
	weapon_ammo[weapon_id] = min(MAX_WEAPON_AMMO, current + amount)
	ammo_changed.emit(weapon_id, weapon_ammo[weapon_id])

func use_grenade() -> bool:
	if grenade_count <= 0:
		return false
	grenade_count -= 1
	grenade_count_changed.emit(grenade_count)
	return true

func add_grenades(amount: int) -> void:
	grenade_count += amount
	grenade_count_changed.emit(grenade_count)

# ============================================================
# POW System
# ============================================================

func rescue_pow() -> void:
	pow_rescued_count += 1
	add_score(500)
	pow_rescued.emit(pow_rescued_count)

# ============================================================
# Internal
# ============================================================

func _reset_state() -> void:
	score = 0
	lives = MAX_LIVES
	player_health = MAX_HEALTH
	current_level = 1
	pow_rescued_count = 0
	current_weapon_id = 0
	enemies_killed = 0
	total_enemies = 0
	weapon_ammo = {
		0: -1,
		1: 200,
		2: 50,
		3: 30,
		4: 150,
	}
	grenade_count = START_GRENADES
	score_changed.emit(score)
	lives_changed.emit(lives)
	health_changed.emit(player_health, MAX_HEALTH)
	weapon_changed.emit(current_weapon_id)
	grenade_count_changed.emit(grenade_count)
	enemies_remaining_changed.emit(enemies_killed, total_enemies)
