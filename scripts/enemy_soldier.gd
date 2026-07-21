extends CharacterBody2D
## EnemySoldier — AI with state machine: Patrol → Spot → Chase → Attack → Hit → Dead

enum AIState { PATROL, SPOT, CHASE, ATTACK, HIT, DEAD }

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

var ai_state: AIState = AIState.PATROL
var hp: int = max_hp
var facing: int = -1
var patrol_origin: Vector2
var patrol_dir: float = 1.0
var attack_cd: float = 0.0
var hit_stun: float = 0.0
var player_ref: Node = null
var bullet_scene: PackedScene
var dead_timer: float = 0.0

var body_rect: ColorRect
var head_rect: ColorRect
var weapon_rect: ColorRect

signal died(position: Vector2)

func _ready() -> void:
	add_to_group("enemies")
	patrol_origin = global_position
	bullet_scene = load("res://scenes/bullet.tscn")
	_create_visuals()
	_find_player()

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
	match ai_state:
		AIState.PATROL:
			velocity.x = patrol_dir * move_speed
		AIState.CHASE:
			var dir := sign(player_ref.global_position.x - global_position.x)
			velocity.x = dir * chase_speed
			facing = int(dir)
		AIState.ATTACK:
			velocity.x = 0
		AIState.HIT:
			velocity.x = 0
		_:
			velocity.x = 0
	move_and_slide()

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
		AIState.SPOT:
			# Brief surprise, then chase
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
				attack_cd = attack_cooldown
		AIState.HIT:
			if hit_stun <= 0:
				ai_state = AIState.CHASE

func _shoot_at_player() -> void:
	if not is_instance_valid(player_ref):
		return
	var dir := (player_ref.global_position - global_position).normalized()
	var bullet := bullet_scene.instantiate()
	bullet.setup(dir, BULLET_SPEED, bullet_damage, Color(1.0, 0.3, 0.2), 0.7, false)
	bullet.global_position = global_position + dir * 20
	get_tree().current_scene.add_child(bullet)
	# Muzzle flash
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.8, 0.2, 0.8)
	flash.size = Vector2(8, 8)
	flash.position = dir * 22 + Vector2(-4, -4)
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.08)
	tw.tween_callback(flash.queue_free)

func take_damage(amount: int) -> void:
	if ai_state == AIState.DEAD:
		return
	hp = max(0, hp - amount)
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

func _die() -> void:
	ai_state = AIState.DEAD
	died.emit(global_position)
	GameManager.add_score(100)
	_spawn_explosion()

func _spawn_explosion() -> void:
	var exp_scene := load("res://scenes/explosion.tscn")
	if exp_scene:
		var fx := exp_scene.instantiate()
		fx.global_position = global_position
		get_tree().current_scene.add_child(fx)

func _create_visuals() -> void:
	body_rect = ColorRect.new()
	body_rect.color = Color(0.8, 0.2, 0.2)
	body_rect.size = Vector2(24, 32)
	body_rect.position = Vector2(-12, -16)
	add_child(body_rect)
	head_rect = ColorRect.new()
	head_rect.color = Color(0.6, 0.5, 0.4)
	head_rect.size = Vector2(16, 14)
	head_rect.position = Vector2(-8, -26)
	add_child(head_rect)
	weapon_rect = ColorRect.new()
	weapon_rect.color = Color(0.2, 0.2, 0.2)
	weapon_rect.size = Vector2(14, 4)
	weapon_rect.position = Vector2(10, -4)
	add_child(weapon_rect)

func _update_visuals() -> void:
	body_rect.scale.x = facing
	body_rect.position.x = -12 * facing
	head_rect.scale.x = facing
	head_rect.position.x = -8 * facing
	weapon_rect.scale.x = facing
	weapon_rect.position.x = 10 if facing == 1 else -24
	if ai_state == AIState.DEAD:
		body_rect.color = Color(0.4, 0.4, 0.4)
		rotation = PI * 0.5
