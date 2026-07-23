extends Area2D
## Grenade — thrown explosive with arc trajectory.
## Applies gravity, bounces off the ground, and detonates on impact or after
## its fuse expires, spawning an Explosion that deals area damage.

# ============================================================
# Exports
# ============================================================

@export var damage: int = 80
@export var radius: float = 100.0
@export var fuse: float = 1.6
@export var from_player: bool = true
@export var gravity: float = 900.0
@export var bounce_damping: float = 0.45

# ============================================================
# Internal
# ============================================================

var _velocity: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _ground_y: float = 1500.0  # populated from level metadata
var _visual: ColorRect
var _detonated: bool = false
var _explosion_scene: PackedScene = preload("res://scenes/explosion.tscn")

# ============================================================
# Lifecycle
# ============================================================

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_create_visual()
	# Discover ground level from any wall StaticBody2D (its top edge).
	# Fallback keeps the default 1500 if discovery fails.
	var walls := get_tree().get_nodes_in_group("walls")
	for w in walls:
		if w is StaticBody2D:
			for c in w.get_children():
				if c is CollisionShape2D and c.shape is RectangleShape2D:
					var rect_shape: RectangleShape2D = c.shape
					var top: float = w.global_position.y - rect_shape.size.y * 0.5
					if top > _ground_y:
						_ground_y = top
					break

func setup(dir: Vector2, spd: float, dmg: int, r: float, src_player: bool = true) -> void:
	_velocity = dir.normalized() * spd
	damage = dmg
	radius = r
	from_player = src_player

func _process(delta: float) -> void:
	if _detonated:
		return
	_age += delta
	# Gravity
	_velocity.y += gravity * delta
	# Ground collision & bounce
	var half_h: float = 12.0
	if global_position.y + half_h >= _ground_y:
		global_position.y = _ground_y - half_h
		if abs(_velocity.y) > 50.0:
			_velocity.y = -_velocity.y * bounce_damping
			_velocity.x *= 0.7
		else:
			_velocity.y = 0.0
			_velocity.x *= 0.9
	global_position += _velocity * delta
	if _age >= fuse:
		_detonate()

# ============================================================
# Detonation
# ============================================================

func _detonate() -> void:
	if _detonated:
		return
	_detonated = true
	if _explosion_scene:
		var fx := _explosion_scene.instantiate()
		fx.global_position = global_position
		fx.damage = damage
		fx.radius = radius
		fx.is_player_explosion = from_player
		# Use a normal (non-small, non-big) explosion; scale via radius.
		get_parent().add_child(fx)
	AudioManager.play_sfx(AudioManager.SFX_EXPLOSION)
	CameraFX.shake(10.0)
	queue_free()

func _on_body_entered(body: Node) -> void:
	# Detonate on contact with enemies/destructibles/vehicles — but NOT on
	# the ground/walls (those are handled by the bounce + fuse logic so the
	# grenade can roll before exploding).
	if body.is_in_group("enemies") or body.is_in_group("destructible") or body.is_in_group("vehicle"):
		_detonate()

# ============================================================
# Visual
# ============================================================

func _create_visual() -> void:
	_visual = ColorRect.new()
	_visual.color = Color(0.3, 0.8, 0.3)
	_visual.size = Vector2(12, 12)
	_visual.position = Vector2(-6, -6)
	add_child(_visual)
