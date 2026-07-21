extends Node2D
## Level — manages level layout, spawning, camera, parallax background, win condition.

const LEVEL_WIDTH: float = 6000.0
const LEVEL_HEIGHT: float = 1920.0
const GROUND_Y: float = 1500.0
const CAMERA_LIMIT_LEFT: float = 0.0
const CAMERA_LIMIT_TOP: float = 0.0
const SCROLL_SPEED: float = 0.5

var player_scene: PackedScene
var enemy_scene: PackedScene
var tank_scene: PackedScene
var hud_scene: PackedScene

var player_node: Node2D
var hud_node: CanvasLayer
var camera: Camera2D
var enemies: Array[Node] = []
var tanks: Array[Node] = []
var level_end_x: float = LEVEL_WIDTH - 200
var boss_spawned: bool = false
var boss_defeated: bool = false
var enemies_killed: int = 0
var total_enemies: int = 0

# Parallax layers
var parallax_bg: ParallaxBackground
var bg_layers: Array[ColorRect] = []

func _ready() -> void:
	_setup_level()
	_spawn_player()
	_spawn_enemies()
	_spawn_tank()
	_spawn_hud()
	_setup_parallax()
	_setup_camera()

func _setup_level() -> void:
	# Create ground
	var ground := StaticBody2D.new()
	ground.add_to_group("walls")
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(LEVEL_WIDTH, 100)
	col.shape = rect
	ground.add_child(col)
	ground.position = Vector2(LEVEL_WIDTH * 0.5, GROUND_Y + 50)
	add_child(ground)
	# Visual ground
	var ground_vis := ColorRect.new()
	ground_vis.color = Color(0.35, 0.25, 0.15)
	ground_vis.size = Vector2(LEVEL_WIDTH, 120)
	ground_vis.position = Vector2(0, GROUND_Y - 10)
	add_child(ground_vis)
	# Back wall (left boundary)
	var wall_l := StaticBody2D.new()
	wall_l.add_to_group("walls")
	var col_l := CollisionShape2D.new()
	var rect_l := RectangleShape2D.new()
	rect_l.size = Vector2(20, LEVEL_HEIGHT)
	col_l.shape = rect_l
	wall_l.add_child(col_l)
	wall_l.position = Vector2(-10, LEVEL_HEIGHT * 0.5)
	add_child(wall_l)

func _spawn_player() -> void:
	player_scene = load("res://scenes/player.tscn")
	player_node = player_scene.instantiate()
	player_node.global_position = Vector2(150, GROUND_Y - 50)
	add_child(player_node)

func _spawn_enemies() -> void:
	enemy_scene = load("res://scenes/enemy_soldier.tscn")
	# Spawn enemies at various positions
	var positions := [
		Vector2(500, GROUND_Y - 50),
		Vector2(800, GROUND_Y - 50),
		Vector2(1200, GROUND_Y - 50),
		Vector2(1600, GROUND_Y - 50),
		Vector2(2000, GROUND_Y - 50),
		Vector2(2500, GROUND_Y - 50),
		Vector2(3000, GROUND_Y - 50),
		Vector2(3500, GROUND_Y - 50),
		Vector2(4000, GROUND_Y - 50),
		Vector2(4500, GROUND_Y - 50),
	]
	for pos in positions:
		var enemy := enemy_scene.instantiate()
		enemy.global_position = pos
		enemy.died.connect(_on_enemy_died)
		add_child(enemy)
		enemies.append(enemy)
	total_enemies = enemies.size()

func _spawn_tank() -> void:
	tank_scene = load("res://scenes/slug_tank.tscn")
	var tank := tank_scene.instantiate()
	tank.global_position = Vector2(2200, GROUND_Y - 60)
	add_child(tank)
	tanks.append(tank)

func _spawn_hud() -> void:
	hud_scene = load("res://scenes/hud.tscn")
	hud_node = hud_scene.instantiate()
	add_child(hud_node)

func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.make_current()
	camera.limit_left = int(CAMERA_LIMIT_LEFT)
	camera.limit_top = int(CAMERA_LIMIT_TOP)
	camera.limit_right = int(LEVEL_WIDTH)
	camera.limit_bottom = int(LEVEL_HEIGHT)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	if player_node:
		camera.global_position = player_node.global_position
	add_child(camera)

func _setup_parallax() -> void:
	parallax_bg = ParallaxBackground.new()
	add_child(parallax_bg)
	# Layer 1: Far sky (slowest)
	_add_parallax_layer(Color(0.15, 0.1, 0.25), Vector2(4000, 1920), Vector2(0.1, 0.0), 0)
	# Layer 2: Distant mountains
	_add_parallax_layer(Color(0.2, 0.15, 0.3), Vector2(4000, 600), Vector2(0.3, 0.0), 400)
	# Layer 3: Mid buildings
	_add_parallax_layer(Color(0.25, 0.2, 0.2), Vector2(4000, 400), Vector2(0.5, 0.0), 800)
	# Layer 4: Near foreground details
	_add_parallax_layer(Color(0.3, 0.25, 0.15), Vector2(4000, 200), Vector2(0.8, 0.0), 1200)

func _add_parallax_layer(color: Color, size: Vector2, scroll_scale: Vector2, y_offset: float) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = scroll_scale
	layer.motion_mirroring = size
	parallax_bg.add_child(layer)
	var rect := ColorRect.new()
	rect.color = color
	rect.size = size
	rect.position = Vector2(0, y_offset)
	layer.add_child(rect)
	bg_layers.append(rect)

func _process(delta: float) -> void:
	if not is_instance_valid(player_node):
		return
	# Camera follows player but stays within bounds
	var cam_x := clampf(player_node.global_position.x, 540, LEVEL_WIDTH - 540)
	camera.global_position.x = cam_x
	camera.global_position.y = player_node.global_position.y - 200
	# Check win condition
	if player_node.global_position.x >= level_end_x and not boss_spawned:
		_spawn_boss()
	# Boss defeated → victory
	if boss_spawned and boss_defeated:
		GameManager.victory()

func _spawn_boss() -> void:
	boss_spawned = true
	var boss_scene := load("res://scenes/enemy_soldier.tscn")
	var boss := boss_scene.instantiate()
	boss.global_position = Vector2(LEVEL_WIDTH - 300, GROUND_Y - 100)
	boss.set("hp", 500)
	boss.set("detection_range", 800.0)
	boss.set("attack_range", 600.0)
	boss.set("attack_cooldown", 0.8)
	boss.set("max_hp", 500)
	boss.scale = Vector2(3.0, 3.0)
	boss.died.connect(_on_boss_died)
	add_child(boss)
	enemies.append(boss)

func _on_enemy_died(pos: Vector2) -> void:
	enemies_killed += 1

func _on_boss_died(pos: Vector2) -> void:
	boss_defeated = true
	GameManager.add_score(5000)
