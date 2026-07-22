extends CharacterBody2D
## EnemySoldier — AI with state machine: Patrol → Spot → Chase → Attack → Hit → Dead
##
## Supports three variants via `enemy_type`:
##   GRUNT    — basic infantry with rifle.
##   SHIELD   — frontal shield; takes reduced damage from the facing direction.
##   BAZOOKA  — slow, long-range, fires a heavy high-damage projectile.
##   BUG      — hopping creature; closes distance by leaping toward the player
##              and body-slams instead of shooting.
## When `is_boss` is true, the soldier gains a two-phase pattern: below 50% HP
## its fire rate doubles, movement speeds up, and every third shot is a
## 3-round fan.

enum AIState { PATROL, SPOT, CHASE, ATTACK, HIT, DEAD }
enum EnemyType { GRUNT, SHIELD, BAZOOKA, BUG }

@export var enemy_type: EnemyType = EnemyType.GRUNT
@export var is_boss: bool = false
@export var move_speed: float = 80.0
@export var chase_speed: float = 140.0
const GRAVITY: float = 980.0
@export var detection_range: float = 350.0
@export var attack_range: float = 250.0
@export var attack_cooldown: float = 1.5
const PATROL_DISTANCE: float = 120.0
@export var max_hp: int = 30
const HIT_STUN_TIME: float = 0.3
const BULLET_SPEED: float = 500.0
@export var bullet_damage: int = 15
const SPOT_TIME: float = 0.3
const SHIELD_FRONT_DAMAGE_MULT: float = 0.2
const BAZOOKA_BULLET_SPEED: float = 320.0
const BAZOOKA_DAMAGE: int = 35
const BAZOOKA_RANGE: float = 480.0
const BAZOOKA_COOLDOWN: float = 2.6
const BUG_JUMP_VELOCITY: float = -420.0
const BUG_JUMP_COOLDOWN: float = 1.2
const BUG_HOP_RANGE: float = 300.0
const BUG_HOP_SPEED_MULT: float = 1.3
const BUG_CONTACT_DAMAGE: int = 15
const BOSS_PHASE2_HP_FRACTION: float = 0.5
const BOSS_FAN_INTERVAL: int = 3
const BOSS_FAN_SPREAD_DEG: float = 18.0

var ai_state: AIState = AIState.PATROL
var hp: int = max_hp
var facing: int = -1
var patrol_origin: Vector2
var patrol_dir: float = 1.0
var attack_cd: float = 0.0
var hit_stun: float = 0.0
var spot_timer: float = 0.0
var player_ref: Node = null
var bullet_scene: PackedScene
var dead_timer: float = 0.0
var _boss_phase2: bool = false
var _boss_shots_fired: int = 0
var bug_jump_cd: float = 0.0  # BUG variant: cooldown between hops

var body_rect: ColorRect
var head_rect: ColorRect
var weapon_rect: ColorRect
var shield_rect: ColorRect

signal died(position: Vector2)

## Explicit boss configuration. Call after add_child() so _ready has run.
func configure_as_boss(hp_value: int, detect: float, atk_range: float, atk_cd: float) -> void:
	is_boss = true
	max_hp = hp_value
	hp = hp_value
	detection_range = detect
	attack_range = atk_range
	attack_cooldown = atk_cd
	scale = Vector2(3.0, 3.0)
	# Re-tint visuals so the boss looks distinct even if created from a grunt.
	if body_rect:
		body_rect.color = Color(0.5, 0.15, 0.6)

func _ready() -> void:
	add_to_group("enemies")
	patrol_origin = global_position
	bullet_scene = load("res://scenes/bullet.tscn")
	_apply_type_defaults()
	_create_visuals()
	_find_player()

func _apply_type_defaults() -> void:
	match enemy_type:
		EnemyType.SHIELD:
			max_hp = max(max_hp, 60)
			move_speed *= 0.7
			chase_speed *= 0.7
			attack_cooldown = max(attack_cooldown, 1.8)
		EnemyType.BAZOOKA:
			bullet_damage = BAZOOKA_DAMAGE
			detection_range = max(detection_range, BAZOOKA_RANGE)
			attack_range = BAZOOKA_RANGE
			attack_cooldown = BAZOOKA_COOLDOWN
			move_speed *= 0.6
			chase_speed *= 0.6
		EnemyType.BUG:
			max_hp = max(max_hp, 20)
			move_speed *= 0.8
			chase_speed *= 0.9
			detection_range = max(detection_range, BUG_HOP_RANGE)
			attack_range = BUG_HOP_RANGE
			attack_cooldown = BUG_JUMP_COOLDOWN
			bullet_damage = BUG_CONTACT_DAMAGE
	hp = max_hp

func _find_player() -> void:
	player_ref = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if ai_state == AIState.DEAD:
		dead_timer += delta
		if dead_timer > 1.0:
			queue_free()
		return
	if hit_stun > 0:
		hit_stun -= delta
		return
	if attack_cd > 0:
		attack_cd -= delta
	if bug_jump_cd > 0:
		bug_jump_cd -= delta
	if spot_timer > 0:
		spot_timer -= delta
	if not is_instance_valid(player_ref):
		_find_player()
		return
	_update_ai(delta)
	_update_visuals()

func _physics_process(delta: float) -> void:
	if ai_state == AIState.DEAD:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	# BUG variant hops toward the player instead of walking/shooting.
	if enemy_type == EnemyType.BUG:
		_update_bug_physics(delta)
		move_and_slide()
		return
	var speed_mult: float = 1.0
	if is_boss and _boss_phase2:
		speed_mult = 1.5
	match ai_state:
		AIState.PATROL:
			velocity.x = patrol_dir * move_speed * speed_mult
		AIState.CHASE:
			var dir := sign(player_ref.global_position.x - global_position.x)
			velocity.x = dir * chase_speed * speed_mult
			facing = int(dir)
		AIState.ATTACK:
			velocity.x = 0
		AIState.HIT:
			velocity.x = 0
		_:
			velocity.x = 0
	move_and_slide()

## BUG variant physics: stands still on the ground, then leaps toward the
## player on a cooldown, retaining horizontal velocity through the arc. The
## leap itself deals contact damage via the player's take_damage on overlap
## (handled in _process through a distance check).
func _update_bug_physics(delta: float) -> void:
	var on_floor: bool = is_on_floor()
	if on_floor:
		velocity.x = 0
	if not is_instance_valid(player_ref):
		_find_player()
		return
	# Only hop when actively chasing/attacking and grounded, with cooldown spent.
	if on_floor and ai_state in [AIState.CHASE, AIState.ATTACK] and bug_jump_cd <= 0:
		var dir := sign(player_ref.global_position.x - global_position.x)
		if dir == 0:
			dir = facing
		facing = int(dir)
		velocity.y = BUG_JUMP_VELOCITY
		velocity.x = dir * chase_speed * BUG_HOP_SPEED_MULT
		bug_jump_cd = BUG_JUMP_COOLDOWN
		AudioManager.play_sfx(AudioManager.SFX_ENEMY_SHOOT)  # reuse as a hop cue
	# Contact damage while overlapping the player (airborne slam or close pass).
	# Only during active engagement — PATROL means it hasn't noticed the player.
	var dist := global_position.distance_to(player_ref.global_position)
	if dist < 30.0 and ai_state in [AIState.CHASE, AIState.ATTACK] and player_ref.has_method("take_damage"):
		player_ref.take_damage(BUG_CONTACT_DAMAGE)

func _update_ai(delta: float) -> void:
	var dist_to_player := global_position.distance_to(player_ref.global_position)
	match ai_state:
		AIState.PATROL:
			# Patrol back and forth
			if abs(global_position.x - patrol_origin.x) > PATROL_DISTANCE:
				patrol_dir *= -1
				facing = int(patrol_dir)
			# Detect player
			if dist_to_player < detection_range:
				ai_state = AIState.SPOT
				spot_timer = SPOT_TIME
		AIState.SPOT:
			# Brief surprise pause, then chase
			if spot_timer <= 0:
				ai_state = AIState.CHASE
		AIState.CHASE:
			facing = int(sign(player_ref.global_position.x - global_position.x))
			if dist_to_player <= attack_range:
				ai_state = AIState.ATTACK
			elif dist_to_player > detection_range * 1.5:
				ai_state = AIState.PATROL
				patrol_origin = global_position
		AIState.ATTACK:
			facing = int(sign(player_ref.global_position.x - global_position.x))
			if dist_to_player > attack_range:
				ai_state = AIState.CHASE
			elif attack_cd <= 0:
				_shoot_at_player()
				attack_cd = _effective_attack_cooldown()
		AIState.HIT:
			if hit_stun <= 0:
				ai_state = AIState.CHASE

func _effective_attack_cooldown() -> float:
	var cd: float = attack_cooldown
	if is_boss and _boss_phase2:
		cd *= 0.5
	return cd

func _shoot_at_player() -> void:
	if enemy_type == EnemyType.BUG:
		return  # BUG doesn't shoot; it hops (handled in _update_bug_physics)
	if not is_instance_valid(player_ref):
		return
	var dir := (player_ref.global_position - global_position).normalized()
	# Boss phase-2 fans every BOSS_FAN_INTERVAL-th shot
	var fan: bool = is_boss and _boss_phase2 and (_boss_shots_fired % BOSS_FAN_INTERVAL == BOSS_FAN_INTERVAL - 1)
	var shots: int = 3 if fan else 1
	var spread_rad: float = deg_to_rad(BOSS_FAN_SPREAD_DEG)
	for i in shots:
		var angle_off: float = 0.0
		if shots > 1:
			angle_off = lerp(-spread_rad, spread_rad, float(i) / float(shots - 1))
		var shot_dir := dir.rotated(angle_off)
		var bullet := bullet_scene.instantiate()
		var spd: float = BULLET_SPEED
		var dmg: int = bullet_damage
		var scl: float = 0.7
		var col: Color = Color(1.0, 0.3, 0.2)
		if enemy_type == EnemyType.BAZOOKA:
			spd = BAZOOKA_BULLET_SPEED
			scl = 1.6
			col = Color(0.9, 0.4, 0.1)
		bullet.setup(shot_dir, spd, dmg, col, scl, false)
		bullet.global_position = global_position + shot_dir * 20
		get_parent().add_child(bullet)
	_boss_shots_fired += 1
	# Muzzle flash
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.8, 0.2, 0.8)
	flash.size = Vector2(8, 8)
	flash.position = dir * 22 + Vector2(-4, -4)
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.08)
	tw.tween_callback(flash.queue_free)
	AudioManager.play_sfx(AudioManager.SFX_ENEMY_SHOOT)

func take_damage(amount: int) -> void:
	if ai_state == AIState.DEAD:
		return
	var actual := amount
	# Shield blocks damage coming from the direction the enemy faces
	# (player on the facing side => bullets hit the shield first).
	if enemy_type == EnemyType.SHIELD and player_ref and is_instance_valid(player_ref):
		var to_player := sign(player_ref.global_position.x - global_position.x)
		if int(to_player) == facing:
			actual = max(1, int(amount * SHIELD_FRONT_DAMAGE_MULT))
	hp = max(0, hp - actual)
	# Boss phase transition
	if is_boss and not _boss_phase2 and float(hp) <= float(max_hp) * BOSS_PHASE2_HP_FRACTION:
		_boss_phase2 = true
		CameraFX.shake(8.0)
	if hp <= 0:
		_die()
	else:
		ai_state = AIState.HIT
		hit_stun = HIT_STUN_TIME
		# Knockback
		velocity.x = -facing * 100
		# Flash red
		body_rect.color = Color(1.0, 0.5, 0.5)
		var tw := create_tween()
		tw.tween_property(body_rect, "color", Color(0.8, 0.2, 0.2), 0.15)
		AudioManager.play_sfx(AudioManager.SFX_ENEMY_HURT)

func _die() -> void:
	ai_state = AIState.DEAD
	died.emit(global_position)
	GameManager.add_score(100 if not is_boss else 5000)
	GameManager.register_enemy_killed()
	_spawn_explosion()
	AudioManager.play_sfx(AudioManager.SFX_ENEMY_DIE)
	if is_boss:
		CameraFX.shake(14.0)

func _spawn_explosion() -> void:
	var exp_scene := load("res://scenes/explosion.tscn")
	if exp_scene:
		var fx := exp_scene.instantiate()
		fx.global_position = global_position
		fx.big = is_boss
		fx.is_player_explosion = true
		get_parent().add_child(fx)

func _create_visuals() -> void:
	var body_color: Color = Color(0.8, 0.2, 0.2)
	var head_color: Color = Color(0.6, 0.5, 0.4)
	var body_size := Vector2(24, 32)
	var body_pos := Vector2(-12, -16)
	var head_size := Vector2(16, 14)
	var head_pos := Vector2(-8, -26)
	match enemy_type:
		EnemyType.SHIELD:
			body_color = Color(0.3, 0.45, 0.7)
		EnemyType.BAZOOKA:
			body_color = Color(0.55, 0.4, 0.2)
		EnemyType.BUG:
			body_color = Color(0.3, 0.7, 0.2)
			head_color = Color(0.2, 0.55, 0.15)
			body_size = Vector2(28, 18)
			body_pos = Vector2(-14, -14)
			head_size = Vector2(12, 10)
			head_pos = Vector2(-6, -22)
		EnemyType.GRUNT, _:
			body_color = Color(0.8, 0.2, 0.2)
	if is_boss:
		body_color = Color(0.5, 0.15, 0.6)
	body_rect = ColorRect.new()
	body_rect.color = body_color
	body_rect.size = body_size
	body_rect.position = body_pos
	add_child(body_rect)
	head_rect = ColorRect.new()
	head_rect.color = head_color
	head_rect.size = head_size
	head_rect.position = head_pos
	add_child(head_rect)
	if enemy_type != EnemyType.BUG:
		weapon_rect = ColorRect.new()
		weapon_rect.color = Color(0.2, 0.2, 0.2)
		weapon_rect.size = Vector2(14, 4)
		weapon_rect.position = Vector2(10, -4)
		add_child(weapon_rect)
	if enemy_type == EnemyType.SHIELD:
		shield_rect = ColorRect.new()
		shield_rect.color = Color(0.7, 0.75, 0.85, 0.85)
		shield_rect.size = Vector2(6, 28)
		shield_rect.position = Vector2(12, -14)
		add_child(shield_rect)

func _update_visuals() -> void:
	# Flip horizontally based on facing. Positions derived from each rect's
	# size so variants with different body dimensions (e.g. BUG) stay centered.
	body_rect.scale.x = facing
	body_rect.position.x = body_rect.size.x * -0.5 * facing
	head_rect.scale.x = facing
	head_rect.position.x = head_rect.size.x * -0.5 * facing
	if weapon_rect:
		weapon_rect.scale.x = facing
		weapon_rect.position.x = (10 if facing == 1 else -24)
	if shield_rect:
		shield_rect.position.x = 12 if facing == 1 else -18
		shield_rect.scale.x = facing
	if ai_state == AIState.DEAD:
		body_rect.color = Color(0.4, 0.4, 0.4)
		rotation = PI * 0.5
