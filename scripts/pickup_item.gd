extends Area2D
## Pickup — collectible item (ammo / health / grenade / weapon).
##
## On body_entered with the player, applies the effect via GameManager and
## despawns. Fields are set by the spawner before add_child().

# ============================================================
# Exports
# ============================================================

@export var pickup_type: int = PickupData.PickupType.AMMO
@export var amount: int = 30
@export var weapon_id: int = 0  # Used when pickup_type == WEAPON or AMMO

# ============================================================
# Internal
# ============================================================

var _visual: ColorRect
var _collected: bool = false

# ============================================================
# Lifecycle
# ============================================================

func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	_create_visual()

func _create_visual() -> void:
	var col: Color = Color(1.0, 1.0, 0.3)
	var sz: Vector2 = Vector2(18, 18)
	match pickup_type:
		PickupData.PickupType.HEALTH:
			col = Color(0.3, 1.0, 0.4)
		PickupData.PickupType.GRENADE:
			col = Color(0.3, 0.8, 0.3)
			sz = Vector2(14, 14)
		PickupData.PickupType.WEAPON:
			col = Color(0.7, 0.5, 0.9)
			sz = Vector2(22, 14)
		PickupData.PickupType.AMMO, _:
			col = Color(1.0, 0.85, 0.2)
	_visual = ColorRect.new()
	_visual.color = col
	_visual.size = sz
	_visual.position = Vector2(-sz.x * 0.5, -sz.y * 0.5)
	add_child(_visual)
	# Gentle bob so pickups are visible
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(_visual, "position:y", -sz.y * 0.5 - 4, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_visual, "position:y", -sz.y * 0.5, 0.4).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return
	_collected = true
	match pickup_type:
		PickupData.PickupType.AMMO:
			GameManager.add_ammo(weapon_id, amount)
		PickupData.PickupType.HEALTH:
			# GameManager.player_health is the single HP source; add_health
			# updates it and emits health_changed for the HUD.
			GameManager.add_health(amount)
		PickupData.PickupType.GRENADE:
			GameManager.add_grenades(amount)
		PickupData.PickupType.WEAPON:
			GameManager.add_ammo(weapon_id, amount)
			GameManager.switch_weapon(weapon_id)
			if body.has_method("select_weapon_external"):
				body.select_weapon_external(weapon_id)
	AudioManager.play_sfx(AudioManager.SFX_PICKUP)
	queue_free()
