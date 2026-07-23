extends Area2D
## Bullet — projectile entity for all weapons.

# ============================================================
# Exports
# ============================================================

@export var speed: float = 800.0
@export var damage: int = 10
@export var direction: Vector2 = Vector2.RIGHT
@export var scale_factor: float = 1.0
@export var color: Color = Color(1.0, 0.87, 0.27)
@export var is_player_bullet: bool = true
@export var lifetime: float = 3.0

# ============================================================
# Internal
# ============================================================

var _velocity: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _visual: ColorRect
var _explosion_scene: PackedScene = preload("res://scenes/explosion.tscn")

# ============================================================
# Lifecycle
# ============================================================

func _ready() -> void:
	_velocity = direction.normalized() * speed
	_create_visual()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	position += _velocity * delta
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	# Off-screen culling — base on the camera's actual visible rect, not the
	# fixed viewport origin (which is wrong for a scrolling camera).
	var cam := get_viewport().get_camera_2d()
	if cam:
		var vr := cam.get_viewport_rect().size
		var center := cam.global_position
		var margin := 200.0
		if global_position.x < center.x - vr.x * 0.5 - margin \
				or global_position.x > center.x + vr.x * 0.5 + margin \
				or global_position.y < center.y - vr.y * 0.5 - margin \
				or global_position.y > center.y + vr.y * 0.5 + margin:
			queue_free()

# ============================================================
# Setup
# ============================================================

func setup(dir: Vector2, spd: float, dmg: int, col: Color, scl: float, from_player: bool = true) -> void:
	direction = dir
	speed = spd
	damage = dmg
	color = col
	scale_factor = scl
	is_player_bullet = from_player

# ============================================================
# Visual
# ============================================================

func _create_visual() -> void:
	var w := 8.0 * scale_factor
	var h := 4.0 * scale_factor
	# Orient bullet shape along travel direction
	var angle := direction.angle()
	_visual = ColorRect.new()
	_visual.color = color
	_visual.size = Vector2(w, h)
	_visual.position = Vector2(-w * 0.5, -h * 0.5)
	_visual.rotation = angle
	add_child(_visual)
	# Add a small glow
	var glow := ColorRect.new()
	glow.color = Color(color.r, color.g, color.b, 0.3)
	glow.size = Vector2(w * 1.8, h * 1.8)
	glow.position = Vector2(-w * 0.9, -h * 0.9)
	glow.rotation = angle
	glow.z_index = -1
	add_child(glow)

# ============================================================
# Collision
# ============================================================

func _on_body_entered(body: Node) -> void:
	if is_player_bullet:
		if body.is_in_group("enemies"):
			if body.has_method("take_damage"):
				body.take_damage(damage)
			_spawn_hit_effect()
			queue_free()
		elif body.is_in_group("destructible"):
			if body.has_method("take_damage"):
				body.take_damage(damage)
			queue_free()
		elif body.is_in_group("walls"):
			_spawn_hit_effect()
			queue_free()
	else:
		if body.is_in_group("player"):
			# Route through the player's own take_damage so i-frames,
			# knockback, and the HURT state apply (instead of mutating
			# GameManager HP directly).
			if body.has_method("take_damage"):
				body.take_damage(damage)
			queue_free()
		elif body.is_in_group("vehicle"):
			if body.has_method("take_damage"):
				body.take_damage(damage)
			queue_free()
		elif body.is_in_group("walls"):
			_spawn_hit_effect()
			queue_free()

func _on_area_entered(area: Area2D) -> void:
	if is_player_bullet and area.is_in_group("enemies"):
		if area.get_parent().has_method("take_damage"):
			area.get_parent().take_damage(damage)
		_spawn_hit_effect()
		queue_free()

func _spawn_hit_effect() -> void:
	if _explosion_scene:
		var fx := _explosion_scene.instantiate()
		fx.global_position = global_position
		fx.small = true
		get_parent().add_child(fx)
