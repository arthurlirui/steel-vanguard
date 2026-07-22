extends CharacterBody2D
## Player — main character with full state machine, weapons, vehicles.

signal died
signal vehicle_state_changed(in_vehicle: bool)

enum State { IDLE, RUN, JUMP, FALL, CROUCH, SHOOT, KNIFE, GRENADE, HURT, DIE, VEHICLE }

const MOVE_SPEED: float = 220.0
const JUMP_VELOCITY: float = -520.0
const GRAVITY: float = 980.0
const ACCEL: float = 1500.0
const FRICTION: float = 1800.0
const MAX_JUMPS: int = 2  # Double jump (1 ground + 1 air)
const MAX_HP: int = 100
const INVINCIBLE_TIME: float = 1.5
const KNIFE_RANGE: float = 45.0
const KNIFE_DAMAGE: int = 30
const KNIFE_COOLDOWN: float = 0.4
const GRENADE_COOLDOWN: float = 0.5
const GRENADE_SPEED: float = 350.0
const GRENADE_DAMAGE: int = 80
const GRENADE_RADIUS: float = 100.0

var current_state: State = State.IDLE
var facing: int = 1
var hp: int = MAX_HP
var invincible: bool = false
var invincible_timer: float = 0.0
var jumps_left: int = MAX_JUMPS  # decremented on each jump, refilled on landing
var can_shoot: bool = true
var shoot_cooldown: float = 0.0
var grenade_cd: float = 0.0
var knife_cd: float = 0.0
var aim_dir: Vector2 = Vector2.RIGHT
var in_vehicle: bool = false
var vehicle_node: Node = null
var blink_timer: float = 0.0
var current_weapon: int = 0
var bullet_scene: PackedScene
var grenade_scene: PackedScene
var spawn_point: Vector2 = Vector2.ZERO
var _dying: bool = false  # guards the death tween so it only runs once

var body_rect: ColorRect
var head_rect: ColorRect
var arm_rect: ColorRect
var weapon_rect: ColorRect
var knife_rect: ColorRect

func _ready() -> void:
	add_to_group("player")
	bullet_scene = load("res://scenes/bullet.tscn")
	grenade_scene = load("res://scenes/grenade.tscn")
	_create_visuals()
	_update_aim_direction()
	spawn_point = global_position
	GameManager.health_changed.emit(hp, MAX_HP)
	GameManager.weapon_changed.emit(current_weapon)

func _process(delta: float) -> void:
	if invincible_timer > 0:
		invincible_timer -= delta
		blink_timer += delta
		if blink_timer > 0.1:
			blink_timer = 0
			visible = !visible
		if invincible_timer <= 0:
			invincible = false
			visible = true
	if shoot_cooldown > 0:
		shoot_cooldown -= delta
		can_shoot = shoot_cooldown <= 0
	if grenade_cd > 0:
		grenade_cd -= delta
	if knife_cd > 0:
		knife_cd -= delta
	if current_state not in [State.HURT, State.DIE]:
		_handle_input()
	_update_state(delta)
	_update_visuals()

func _handle_input() -> void:
	if in_vehicle:
		_handle_vehicle_input()
		return
	# Direct weapon select via number keys 1-5
	for w in range(5):
		var action_name := "weapon_slot_%d" % (w + 1)
		if InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name):
			_select_weapon(w)
			return
	# Cycle weapon via the generic "switch_weapon" action (B key, etc.)
	if Input.is_action_just_pressed("switch_weapon"):
		_cycle_weapon()
	_update_aim_direction()
	# Auto weapons fire on hold; semi-auto weapons fire only on press edge.
	var wdata := WeaponData.get_weapon(current_weapon)
	var is_auto: bool = wdata.get("auto", false)
	var fire_held: bool = Input.is_action_pressed("shoot")
	var fire_trigger: bool = fire_held if is_auto else Input.is_action_just_pressed("shoot")
	if fire_trigger and can_shoot:
		_shoot()
	if Input.is_action_just_pressed("grenade") and grenade_cd <= 0:
		_throw_grenade()
	if not fire_held and knife_cd <= 0:
		_try_melee()
	if Input.is_action_just_pressed("enter_vehicle"):
		_try_enter_vehicle()

func _handle_vehicle_input() -> void:
	if Input.is_action_just_pressed("enter_vehicle"):
		_exit_vehicle()
		return
	_update_aim_direction()
	if Input.is_action_pressed("shoot") and can_shoot:
		_shoot_from_vehicle()
	if Input.is_action_just_pressed("grenade") and grenade_cd <= 0:
		_fire_tank_cannon()

func _update_aim_direction() -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		dir.x += 1
	if Input.is_action_pressed("move_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_up"):
		dir.y -= 1
	if Input.is_action_pressed("crouch"):
		dir.y += 1
	if dir == Vector2.ZERO:
		aim_dir = Vector2(facing, 0)
	else:
		aim_dir = dir.normalized()
	if aim_dir.x > 0.1:
		facing = 1
	elif aim_dir.x < -0.1:
		facing = -1

func _physics_process(delta: float) -> void:
	if current_state == State.DIE or in_vehicle:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var input_x: float = 0.0
	if current_state not in [State.HURT, State.GRENADE]:
		if Input.is_action_pressed("move_left"):
			input_x -= 1
		if Input.is_action_pressed("move_right"):
			input_x += 1
	var crouching: bool = Input.is_action_pressed("crouch") and is_on_floor()
	if current_state == State.SHOOT:
		input_x = 0
	if crouching:
		input_x = 0
		current_state = State.CROUCH
	elif input_x != 0:
		if is_on_floor() and current_state != State.SHOOT:
			current_state = State.RUN
		velocity.x = move_toward(velocity.x, input_x * MOVE_SPEED, ACCEL * delta)
		facing = int(sign(input_x)) if input_x != 0 else facing
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		if is_on_floor() and current_state not in [State.SHOOT, State.HURT, State.GRENADE]:
			current_state = State.IDLE
	if Input.is_action_just_pressed("jump") and jumps_left > 0 and not crouching:
		velocity.y = JUMP_VELOCITY
		jumps_left -= 1
		current_state = State.JUMP
		AudioManager.play_sfx(AudioManager.SFX_PLAYER_JUMP)
	if not is_on_floor():
		if velocity.y < 0:
			current_state = State.JUMP
		else:
			current_state = State.FALL
	move_and_slide()
	# Refill jumps whenever grounded. Placed after move_and_slide() so the
	# "just left the ground" frame doesn't immediately reset the counter.
	if is_on_floor():
		jumps_left = MAX_JUMPS

func _update_state(delta: float) -> void:
	match current_state:
		State.SHOOT:
			if not Input.is_action_pressed("shoot"):
				current_state = State.IDLE if is_on_floor() else State.FALL
		State.KNIFE:
			if knife_cd <= 0:
				current_state = State.IDLE
		State.GRENADE:
			if grenade_cd <= 0:
				current_state = State.IDLE
		State.HURT:
			if invincible_timer <= 0:
				current_state = State.IDLE

func _shoot() -> void:
	var wdata := WeaponData.get_weapon(current_weapon)
	can_shoot = false
	shoot_cooldown = wdata["fire_rate"]
	current_state = State.SHOOT
	GameManager.consume_ammo(current_weapon, 1)
	var bullet_count: int = wdata["bullets_per_shot"]
	var spread_rad: float = deg_to_rad(wdata["spread"])
	for i in bullet_count:
		var bullet := bullet_scene.instantiate()
		var spread_angle: float = 0.0
		if bullet_count > 1:
			spread_angle = lerp(-spread_rad, spread_rad, float(i) / float(bullet_count - 1))
		var dir := aim_dir.rotated(spread_angle)
		bullet.setup(dir, wdata["bullet_speed"], wdata["damage"], wdata["color"], wdata["bullet_scale"], true)
		bullet.global_position = global_position + aim_dir * 20
		get_parent().add_child(bullet)
	_spawn_muzzle_flash()
	AudioManager.play_sfx(AudioManager.SFX_PLAYER_SHOOT)

func _shoot_from_vehicle() -> void:
	can_shoot = false
	shoot_cooldown = 0.08
	var bullet := bullet_scene.instantiate()
	bullet.setup(aim_dir, 1000.0, 8, Color(1.0, 0.6, 0.2), 0.6, true)
	bullet.global_position = global_position + aim_dir * 30
	get_parent().add_child(bullet)
	AudioManager.play_sfx(AudioManager.SFX_PLAYER_SHOOT)

func _fire_tank_cannon() -> void:
	if not vehicle_node:
		return
	grenade_cd = 1.0
	var bullet := bullet_scene.instantiate()
	bullet.setup(aim_dir, 600.0, 80, Color(0.9, 0.3, 0.1), 2.0, true)
	bullet.global_position = global_position + aim_dir * 40
	get_parent().add_child(bullet)
	CameraFX.shake(8.0)
	AudioManager.play_sfx(AudioManager.SFX_TANK_CANNON)

func _try_melee() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) < KNIFE_RANGE:
			current_state = State.KNIFE
			knife_cd = KNIFE_COOLDOWN
			if enemy.has_method("take_damage"):
				enemy.take_damage(KNIFE_DAMAGE)
			# Show knife visual briefly
			if knife_rect:
				knife_rect.visible = true
				var tw := create_tween()
				tw.tween_property(knife_rect, "visible", false, 0.2)
			AudioManager.play_sfx(AudioManager.SFX_PLAYER_MELEE)
			break

func _throw_grenade() -> void:
	if not GameManager.use_grenade():
		return
	grenade_cd = GRENADE_COOLDOWN
	current_state = State.GRENADE
	# Thrown grenade — uses the dedicated grenade scene (arc + explosion).
	var grenade := grenade_scene.instantiate()
	var throw_dir := Vector2(facing, -1.5).normalized()
	grenade.setup(throw_dir, GRENADE_SPEED, GRENADE_DAMAGE, GRENADE_RADIUS, true)
	grenade.global_position = global_position + Vector2(0, -10)
	get_parent().add_child(grenade)
	AudioManager.play_sfx(AudioManager.SFX_PLAYER_GRENADE)

func _select_weapon(weapon_id: int) -> void:
	if weapon_id < 0 or weapon_id > 4:
		return
	if GameManager.weapon_ammo.get(weapon_id, 0) == 0:
		return  # Can't select an empty weapon
	current_weapon = weapon_id
	GameManager.switch_weapon(weapon_id)

## Called by pickups to directly select a weapon after switch_weapon ran.
func select_weapon_external(weapon_id: int) -> void:
	current_weapon = weapon_id

## Restores HP from a health pickup; clamps to MAX_HP.
func heal(amount: int) -> void:
	hp = min(MAX_HP, hp + amount)

func _cycle_weapon() -> void:
	var next_w := current_weapon
	for i in range(5):
		next_w = (next_w + 1) % 5
		if GameManager.weapon_ammo.get(next_w, 0) != 0:
			current_weapon = next_w
			GameManager.switch_weapon(current_weapon)
			return
	# If all else fails, go to pistol
	current_weapon = 0
	GameManager.switch_weapon(0)

func _spawn_muzzle_flash() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.9, 0.3, 0.8)
	flash.size = Vector2(12, 12)
	flash.position = aim_dir * 25 + Vector2(-6, -6)
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.08)
	tw.tween_callback(flash.queue_free)

func take_damage(amount: int) -> void:
	if invincible or current_state == State.DIE:
		return
	hp = max(0, hp - amount)
	invincible = true
	invincible_timer = INVINCIBLE_TIME
	current_state = State.HURT
	velocity.x = -facing * 150
	velocity.y = -200
	GameManager.player_take_damage(amount)
	AudioManager.play_sfx(AudioManager.SFX_PLAYER_HURT)
	CameraFX.shake(4.0)
	if hp <= 0:
		_die()

func _die() -> void:
	if _dying:
		return
	_dying = true
	current_state = State.DIE
	died.emit()
	_spawn_explosion()
	AudioManager.play_sfx(AudioManager.SFX_PLAYER_DIE)
	CameraFX.shake(12.0)
	# Defer respawn/game-over; GameManager._lose_life is the single source of
	# truth for whether lives remain. If it already triggered game_over, the
	# state will be GAME_OVER by the time the tween fires.
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(func():
		_dying = false
		if GameManager.current_state == GameManager.GameState.GAME_OVER:
			return  # HUD overlay handles restart
		if GameManager.current_state == GameManager.GameState.VICTORY:
			return
		respawn()
	)

func respawn() -> void:
	hp = MAX_HP
	current_state = State.IDLE
	invincible = true
	invincible_timer = 3.0
	global_position = spawn_point
	velocity = Vector2.ZERO
	GameManager.player_health = MAX_HP
	GameManager.health_changed.emit(hp, MAX_HP)

func _spawn_explosion() -> void:
	var exp_scene := load("res://scenes/explosion.tscn")
	if exp_scene:
		var fx := exp_scene.instantiate()
		fx.global_position = global_position
		fx.is_player_explosion = true
		get_parent().add_child(fx)

# ============================================================
# Vehicle
# ============================================================

func _try_enter_vehicle() -> void:
	var vehicles := get_tree().get_nodes_in_group("vehicle")
	for v in vehicles:
		if is_instance_valid(v) and global_position.distance_to(v.global_position) < 80:
			in_vehicle = true
			vehicle_node = v
			v.set_driver(self)
			visible = false
			vehicle_state_changed.emit(true)
			GameManager.vehicle_entered.emit()
			AudioManager.play_sfx(AudioManager.SFX_PLAYER_VEHICLE_IN)
			break

func _exit_vehicle() -> void:
	if not vehicle_node:
		return
	vehicle_node.remove_driver()
	vehicle_node = null
	in_vehicle = false
	visible = true
	invincible = true
	invincible_timer = 2.0
	global_position += Vector2(0, -30)
	vehicle_state_changed.emit(false)
	GameManager.vehicle_exited.emit()
	AudioManager.play_sfx(AudioManager.SFX_PLAYER_VEHICLE_OUT)

# ============================================================
# Visuals
# ============================================================

func _create_visuals() -> void:
	# Body
	body_rect = ColorRect.new()
	body_rect.color = Color(0.27, 0.53, 1.0)  # Blue
	body_rect.size = Vector2(28, 36)
	body_rect.position = Vector2(-14, -18)
	add_child(body_rect)
	# Head
	head_rect = ColorRect.new()
	head_rect.color = Color(0.95, 0.82, 0.65)  # Skin
	head_rect.size = Vector2(20, 18)
	head_rect.position = Vector2(-10, -30)
	add_child(head_rect)
	# Arm
	arm_rect = ColorRect.new()
	arm_rect.color = Color(0.2, 0.4, 0.8)
	arm_rect.size = Vector2(8, 20)
	arm_rect.position = Vector2(10, -8)
	add_child(arm_rect)
	# Weapon
	weapon_rect = ColorRect.new()
	weapon_rect.color = Color(0.3, 0.3, 0.3)
	weapon_rect.size = Vector2(18, 6)
	weapon_rect.position = Vector2(14, -4)
	add_child(weapon_rect)
	# Knife (hidden by default)
	knife_rect = ColorRect.new()
	knife_rect.color = Color(0.9, 0.9, 0.95)
	knife_rect.size = Vector2(15, 3)
	knife_rect.position = Vector2(20, -2)
	knife_rect.visible = false
	add_child(knife_rect)

func _update_visuals() -> void:
	# Flip based on facing
	body_rect.scale.x = facing
	body_rect.position.x = -14 * facing
	head_rect.scale.x = facing
	head_rect.position.x = -10 * facing
	arm_rect.scale.x = facing
	arm_rect.position.x = 10 if facing == 1 else -18
	weapon_rect.scale.x = facing
	weapon_rect.position.x = 14 if facing == 1 else -32
	knife_rect.scale.x = facing
	knife_rect.position.x = 20 if facing == 1 else -35
	# Crouch visual
	if current_state == State.CROUCH:
		body_rect.size = Vector2(28, 20)
		body_rect.position.y = -2
		head_rect.position.y = -16
		arm_rect.position.y = 6
		weapon_rect.position.y = 10
	else:
		body_rect.size = Vector2(28, 36)
		body_rect.position.y = -18
		head_rect.position.y = -30
		arm_rect.position.y = -8
		weapon_rect.position.y = -4
	# Color tint by state
	match current_state:
		State.HURT:
			body_rect.color = Color(1.0, 0.3, 0.3)
		State.DIE:
			body_rect.color = Color(0.4, 0.4, 0.4)
		_:
			body_rect.color = Color(0.27, 0.53, 1.0)
	# Aim direction visual — rotate weapon
	var aim_angle := aim_dir.angle()
	weapon_rect.rotation = aim_angle
	arm_rect.rotation = aim_angle
