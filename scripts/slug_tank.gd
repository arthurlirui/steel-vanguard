extends CharacterBody2D
## SlugTank — SV-001 style vehicle with Vulcan cannon and main cannon.

const MOVE_SPEED: float = 150.0
const JUMP_VELOCITY: float = -400.0
const GRAVITY: float = 980.0
const MAX_HP: int = 200
const CANNON_COOLDOWN: float = 1.0
const VULCAN_COOLDOWN: float = 0.08

var hp: int = MAX_HP
var has_driver: bool = false
var driver_node: Node = null
var facing: int = 1
var aim_dir: Vector2 = Vector2.RIGHT
var cannon_cd: float = 0.0
var vulcan_cd: float = 0.0

var body_rect: ColorRect
var turret_rect: ColorRect
var cannon_rect: ColorRect
var track_rect: ColorRect

signal destroyed

func _ready() -> void:
	add_to_group("vehicle")
	_create_visuals()

func _process(delta: float) -> void:
	if cannon_cd > 0:
		cannon_cd -= delta
	if vulcan_cd > 0:
		vulcan_cd -= delta
	if has_driver and is_instance_valid(driver_node):
		aim_dir = driver_node.aim_dir
		facing = driver_node.facing
	_update_visuals()

func _physics_process(delta: float) -> void:
	if not has_driver:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var input_x: float = 0.0
	if Input.is_action_pressed("move_left"):
		input_x -= 1
	if Input.is_action_pressed("move_right"):
		input_x += 1
	velocity.x = input_x * MOVE_SPEED
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	move_and_slide()

func set_driver(player: Node) -> void:
	has_driver = true
	driver_node = player

func remove_driver() -> void:
	has_driver = false
	driver_node = null

func take_damage(amount: int) -> void:
	if not has_driver:
		return
	hp = max(0, hp - amount)
	# Flash
	body_rect.color = Color(1.0, 0.5, 0.5)
	var tw := create_tween()
	tw.tween_property(body_rect, "color", Color(0.27, 0.67, 0.27), 0.15)
	if hp <= 0:
		_destroy()

func _destroy() -> void:
	destroyed.emit()
	_spawn_explosion()
	if has_driver and is_instance_valid(driver_node):
		driver_node._exit_vehicle()
		driver_node.take_damage(30)
	queue_free()

func _spawn_explosion() -> void:
	var exp_scene := load("res://scenes/explosion.tscn")
	if exp_scene:
		var fx := exp_scene.instantiate()
		fx.global_position = global_position
		fx.big = true
		get_tree().current_scene.add_child(fx)

func _create_visuals() -> void:
	# Tank body
	body_rect = ColorRect.new()
	body_rect.color = Color(0.27, 0.67, 0.27)
	body_rect.size = Vector2(60, 36)
	body_rect.position = Vector2(-30, -18)
	add_child(body_rect)
	# Turret
	turret_rect = ColorRect.new()
	turret_rect.color = Color(0.2, 0.5, 0.2)
	turret_rect.size = Vector2(36, 24)
	turret_rect.position = Vector2(-18, -34)
	add_child(turret_rect)
	# Cannon barrel
	cannon_rect = ColorRect.new()
	cannon_rect.color = Color(0.15, 0.15, 0.15)
	cannon_rect.size = Vector2(30, 6)
	cannon_rect.position = Vector2(12, -26)
	add_child(cannon_rect)
	# Tracks
	track_rect = ColorRect.new()
	track_rect.color = Color(0.2, 0.2, 0.2)
	track_rect.size = Vector2(64, 12)
	track_rect.position = Vector2(-32, 12)
	add_child(track_rect)

func _update_visuals() -> void:
	body_rect.scale.x = facing
	body_rect.position.x = -30 * facing
	turret_rect.scale.x = facing
	turret_rect.position.x = -18 * facing
	cannon_rect.scale.x = facing
	cannon_rect.position.x = 12 if facing == 1 else -42
	# Rotate cannon to aim
	cannon_rect.rotation = aim_dir.angle()
	# No driver → dim
	if not has_driver:
		body_rect.color = Color(0.4, 0.5, 0.4)
	else:
		if body_rect.color == Color(0.4, 0.5, 0.4):
			body_rect.color = Color(0.27, 0.67, 0.27)
