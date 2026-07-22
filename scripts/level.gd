extends Node2D
## Level — manages level layout, spawning, camera, parallax background, win condition.

const LEVEL_WIDTH: float = 6000.0
const LEVEL_HEIGHT: float = 1920.0
const GROUND_Y: float = 1500.0
const CAMERA_LIMIT_LEFT: float = 0.0
const CAMERA_LIMIT_TOP: float = 0.0
const CAMERA_FOLLOW_SPEED: float = 5.0
const CAMERA_Y: float = GROUND_Y - 400.0
const ENEMY_DROP_CHANCE: float = 0.35

var player_scene: PackedScene
var enemy_scene: PackedScene
var tank_scene: PackedScene
var hud_scene: PackedScene
var pickup_scene: PackedScene
var pow_scene: PackedScene
var destructible_scene: PackedScene

var player_node: Node2D
var hud_node: CanvasLayer
var camera: Camera2D
var enemies: Array[Node] = []
var tanks: Array[Node] = []
var level_end_x: float = LEVEL_WIDTH - 200
var boss_spawned: bool = false
var boss_defeated: bool = false

# Parallax layers
var parallax_bg: ParallaxBackground

func _ready() -> void:
	_setup_level()
	_spawn_player()
	_spawn_enemies()
	_spawn_tank()
	_spawn_destructibles()
	_spawn_pow_hostages()
	_spawn_pickups()
	_spawn_hud()
	_setup_parallax()
	_setup_camera()
	# Enter play state — without this, GameManager stays in MENU and
	# player_take_damage (and other PLAYING-gated logic) would no-op.
	GameManager.total_enemies = enemies.size()
	GameManager.enemies_killed = 0
	GameManager.enemies_remaining_changed.emit(0, GameManager.total_enemies)
	GameManager.start_game()

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
	# (x, type) pairs. Type: 0=grunt, 1=shield, 2=bazooka, 3=bug (hopper)
	var spawns := [
		[500, 0], [800, 0], [1100, 3], [1200, 1], [1600, 0], [2000, 2],
		[2400, 3], [2500, 0], [3000, 1], [3500, 0], [4000, 2], [4300, 3], [4500, 1],
	]
	for entry in spawns:
		var x: float = entry[0]
		var type: int = entry[1]
		var enemy := enemy_scene.instantiate()
		enemy.global_position = Vector2(x, GROUND_Y - 50)
		enemy.enemy_type = type
		enemy.died.connect(_on_enemy_died)
		add_child(enemy)
		enemies.append(enemy)

func _spawn_tank() -> void:
	tank_scene = load("res://scenes/slug_tank.tscn")
	var tank := tank_scene.instantiate()
	tank.global_position = Vector2(2200, GROUND_Y - 60)
	add_child(tank)
	tanks.append(tank)

func _spawn_destructibles() -> void:
	destructible_scene = load("res://scenes/destructible.tscn")
	var positions := [700, 1400, 2300, 3200, 4200, 5200]
	for x in positions:
		var d := destructible_scene.instantiate()
		d.global_position = Vector2(x, GROUND_Y - 40)
		add_child(d)

func _spawn_pow_hostages() -> void:
	pow_scene = load("res://scenes/pow_hostage.tscn")
	var positions := [1800, 3300, 5000]
	for x in positions:
		var p := pow_scene.instantiate()
		p.global_position = Vector2(x, GROUND_Y - 40)
		add_child(p)

func _spawn_pickups() -> void:
	pickup_scene = load("res://scenes/pickup.tscn")
	# Pre-placed ammo/health/grenade caches
	_spawn_pickup(Vector2(1100, GROUND_Y - 30), PickupData.PickupType.HEALTH, 25)
	_spawn_pickup(Vector2(2800, GROUND_Y - 30), PickupData.PickupType.GRENADE, 5)
	_spawn_pickup(Vector2(3800, GROUND_Y - 30), PickupData.PickupType.WEAPON, 1, 120)  # HMG
	_spawn_pickup(Vector2(4800, GROUND_Y - 30), PickupData.PickupType.HEALTH, 50)

func _spawn_pickup(pos: Vector2, type: int, amount: int, weapon_id: int = 0) -> void:
	var p := pickup_scene.instantiate()
	p.global_position = pos
	p.pickup_type = type
	p.amount = amount
	p.weapon_id = weapon_id
	add_child(p)

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
	# We drive the position ourselves via lerp in _process for stable,
	# jitter-free following; smoothing on the Camera2D would fight our updates.
	camera.position_smoothing_enabled = false
	if player_node:
		camera.global_position = Vector2(player_node.global_position.x, CAMERA_Y)
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

func _process(delta: float) -> void:
	if not is_instance_valid(player_node):
		return
	# Camera follows player smoothly. Y is fixed (no jump bob); X clamped to level bounds.
	var target_x := clampf(player_node.global_position.x, 540, LEVEL_WIDTH - 540)
	var target := Vector2(target_x, CAMERA_Y)
	camera.global_position = camera.global_position.lerp(target, clampf(delta * CAMERA_FOLLOW_SPEED, 0.0, 1.0))
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
	boss.died.connect(_on_boss_died)
	add_child(boss)
	# Configure after add_child so _ready has applied defaults; configure_as_boss
	# overwrites HP/detection/attack fields deterministically (avoids relying on
	# the order of set() vs _ready's hp=max_hp).
	boss.configure_as_boss(500, 800.0, 600.0, 0.8)
	enemies.append(boss)
	GameManager.total_enemies += 1
	GameManager.enemies_remaining_changed.emit(GameManager.enemies_killed, GameManager.total_enemies)

func _on_enemy_died(pos: Vector2) -> void:
	# register_enemy_killed is invoked by the enemy itself (single source of
	# truth for scoring); here we just spawn a chance-based drop.
	if randf() < ENEMY_DROP_CHANCE:
		var pickup_scene_res := load("res://scenes/pickup.tscn")
		if pickup_scene_res:
			var p := pickup_scene_res.instantiate()
			p.global_position = pos + Vector2(0, -10)
			# 60% small ammo, 40% grenade
			if randf() < 0.6:
				p.pickup_type = PickupData.PickupType.AMMO
				p.amount = 30
				p.weapon_id = GameManager.current_weapon_id
			else:
				p.pickup_type = PickupData.PickupType.GRENADE
				p.amount = 1
			add_child(p)

func _on_boss_died(pos: Vector2) -> void:
	boss_defeated = true
