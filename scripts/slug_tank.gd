extends CharacterBody2D
## SlugTank — SV-001 style vehicle with Vulcan cannon and main cannon.
## Per design, the tank cannot jump.

const MOVE_SPEED: float = 150.0
const GRAVITY: float = 980.0
const MAX_HP: int = 200

var hp: int = MAX_HP
var has_driver: bool = false
var driver_node: Node = null
var facing: int = 1
var aim_dir: Vector2 = Vector2.RIGHT

var body_rect: ColorRect
var turret_rect: ColorRect
var cannon_rect: ColorRect
var track_rect: ColorRect
var _explosion_scene: PackedScene = preload("res://scenes/explosion.tscn")

const _COLOR_NORMAL := Color(0.27, 0.67, 0.27)
const _COLOR_EMPTY := Color(0.4, 0.5, 0.4)

signal destroyed

func _ready() -> void:
	add_to_group("vehicle")
	_create_visuals()

func _process(delta: float) -> void:
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
	# Tank cannot jump — no vertical impulse here.
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
	tw.tween_property(body_rect, "color", _COLOR_NORMAL, 0.15)
	AudioManager.play_sfx(AudioManager.SFX_TANK_HIT)
	CameraFX.shake(3.0)
	if hp <= 0:
		_destroy()

func _destroy() -> void:
	destroyed.emit()
	_spawn_explosion()
	AudioManager.play_sfx(AudioManager.SFX_TANK_EXPLODE)
	CameraFX.shake(14.0)
	if has_driver and is_instance_valid(driver_node):
		driver_node._exit_vehicle()
		# The exit grants i-frames, but apply damage anyway — if i-frames
		# absorb it, so be it (intended eject protection).
		driver_node.take_damage(30)
	queue_free()

func _spawn_explosion() -> void:
	if _explosion_scene:
		var fx := _explosion_scene.instantiate()
		fx.global_position = global_position
		fx.big = true
		fx.is_player_explosion = true
		get_parent().add_child(fx)

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
	# Driver state drives the body tint directly (no float-== comparison).
	body_rect.color = _COLOR_EMPTY if not has_driver else _COLOR_NORMAL
