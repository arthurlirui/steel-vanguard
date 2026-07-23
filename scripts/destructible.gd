extends StaticBody2D
## Destructible — a crate/barrel that takes damage and explodes, dropping loot.
##
## Added to the "destructible" group so bullets and explosions can find it.
## Calls destroy() (the legacy API name kept for bullet.gd compatibility) when
## HP reaches zero; spawns an explosion and an optional pickup.

# ============================================================
# Exports
# ============================================================

@export var max_hp: int = 20
@export var drop_chance: float = 0.5
@export var drop_type: int = 0  # PickupData.PickupType
@export var drop_amount: int = 20
@export var drop_weapon_id: int = 0

# ============================================================
# Internal
# ============================================================

var hp: int = 20
var _visual: ColorRect
var _explosion_scene: PackedScene = preload("res://scenes/explosion.tscn")
var _pickup_scene: PackedScene = preload("res://scenes/pickup.tscn")

# ============================================================
# Lifecycle
# ============================================================

func _ready() -> void:
	add_to_group("destructible")
	hp = max_hp
	_create_visual()

func _create_visual() -> void:
	_visual = ColorRect.new()
	_visual.color = Color(0.55, 0.4, 0.2)
	_visual.size = Vector2(40, 40)
	_visual.position = Vector2(-20, -20)
	add_child(_visual)
	# X stripe for a "crate" look
	var stripe := ColorRect.new()
	stripe.color = Color(0.35, 0.25, 0.1)
	stripe.size = Vector2(40, 6)
	stripe.position = Vector2(-20, -3)
	add_child(stripe)

# ============================================================
# Damage
# ============================================================

func take_damage(amount: int) -> void:
	if hp <= 0:
		return
	hp = max(0, hp - amount)
	# Flash
	if _visual:
		_visual.color = Color(1.0, 0.6, 0.3)
		var tw := create_tween()
		tw.tween_property(_visual, "color", Color(0.55, 0.4, 0.2), 0.1)
	if hp <= 0:
		destroy()

## Public alias used by bullet.gd's destructible branch.
func destroy() -> void:
	if hp > 0:
		hp = 0
	if _explosion_scene:
		var fx := _explosion_scene.instantiate()
		fx.global_position = global_position
		fx.is_player_explosion = true
		get_parent().add_child(fx)
	AudioManager.play_sfx(AudioManager.SFX_EXPLOSION)
	CameraFX.shake(4.0)
	_maybe_drop()
	queue_free()

func _maybe_drop() -> void:
	if randf() > drop_chance:
		return
	if not _pickup_scene:
		return
	var p := _pickup_scene.instantiate()
	p.global_position = global_position
	p.pickup_type = drop_type
	p.amount = drop_amount
	p.weapon_id = drop_weapon_id
	get_parent().add_child(p)
