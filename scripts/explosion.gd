extends Area2D
## Explosion — visual effect with optional damage radius.

@export var big: bool = false
@export var small: bool = false
@export var damage: int = 0
@export var radius: float = 80.0
## When true, this explosion does NOT damage the player (player-caused).
## When false (enemy/environment), it WILL damage the player if in radius.
@export var is_player_explosion: bool = true

var _age: float = 0.0
var _lifetime: float = 0.5
var _rect: ColorRect
var _glow: ColorRect
var _hit_done: bool = false

func _ready() -> void:
	# Scale based on type, but only fill in defaults for fields the spawner
	# did NOT already set. grenade.gd assigns damage/radius BEFORE add_child,
	# so we must not clobber them here (the prior bug made every grenade deal
	# a flat 20 damage / 80 radius regardless of setup()).
	if big:
		radius = 150.0 if radius == 0.0 else radius
		damage = 50 if damage == 0 else damage
		_lifetime = 0.8
	elif small:
		radius = 40.0 if radius == 0.0 else radius
		damage = 0
		_lifetime = 0.3
	else:
		radius = 80.0 if radius == 0.0 else radius
		damage = 20 if damage == 0 else damage
		_lifetime = 0.5
	_create_visual()
	# Apply damage in radius (once)
	if damage > 0:
		_apply_area_damage()
	# Screen shake
	_shake_screen()

func _process(delta: float) -> void:
	_age += delta
	var t := _age / _lifetime
	if _rect:
		var scale_val := 1.0 + t * 1.5
		_rect.scale = Vector2(scale_val, scale_val)
		_rect.modulate.a = 1.0 - t
	if _glow:
		_glow.modulate.a = (1.0 - t) * 0.5
	if _age >= _lifetime:
		queue_free()

func _create_visual() -> void:
	var size_val: float = radius * 0.6
	var col: Color = Color(1.0, 0.6, 0.1) if big else Color(1.0, 0.7, 0.2)
	_glow = ColorRect.new()
	_glow.color = Color(col.r, col.g, col.b, 0.4)
	_glow.size = Vector2(size_val * 2.5, size_val * 2.5)
	_glow.position = Vector2(-size_val * 1.25, -size_val * 1.25)
	_glow.z_index = -1
	add_child(_glow)
	_rect = ColorRect.new()
	_rect.color = col
	_rect.size = Vector2(size_val, size_val)
	_rect.position = Vector2(-size_val * 0.5, -size_val * 0.5)
	add_child(_rect)

func _apply_area_damage() -> void:
	var bodies := get_tree().get_nodes_in_group("enemies")
	for body in bodies:
		if is_instance_valid(body) and global_position.distance_to(body.global_position) <= radius:
			if body.has_method("take_damage"):
				body.take_damage(damage)
	# Damage the player only for non-player (enemy/environment) explosions
	if not is_player_explosion:
		var player := get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player) and global_position.distance_to(player.global_position) <= radius:
			if player.has_method("take_damage"):
				player.take_damage(damage)
	# Damage destructibles regardless of source
	var dests := get_tree().get_nodes_in_group("destructible")
	for d in dests:
		if is_instance_valid(d) and global_position.distance_to(d.global_position) <= radius:
			if d.has_method("take_damage"):
				d.take_damage(damage)

func _shake_screen() -> void:
	var amount := 4.0 if small else (12.0 if big else 6.0)
	CameraFX.shake(amount)
