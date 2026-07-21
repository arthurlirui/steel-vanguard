class_name WeaponData
## Static weapon definitions for Steel Vanguard.

extends RefCounted

# ============================================================
# Weapon IDs
# ============================================================

enum WeaponID { PISTOL, HMG, SHOTGUN, ROCKET, FLAMETHROWER }

# ============================================================
# Weapon Definition Dictionary
# ============================================================

const WEAPONS: Dictionary = {
	WeaponID.PISTOL: {
		"id": WeaponID.PISTOL,
		"name": "Pistol",
		"damage": 10,
		"fire_rate": 0.35,
		"ammo": -1,
		"bullet_speed": 800.0,
		"spread": 0.0,
		"bullets_per_shot": 1,
		"bullet_scale": 0.8,
		"color": Color(1.0, 0.87, 0.27),
		"auto": false,
	},
	WeaponID.HMG: {
		"id": WeaponID.HMG,
		"name": "Heavy MG",
		"damage": 8,
		"fire_rate": 0.08,
		"ammo": 200,
		"bullet_speed": 1000.0,
		"spread": 5.0,
		"bullets_per_shot": 1,
		"bullet_scale": 0.6,
		"color": Color(1.0, 0.6, 0.2),
		"auto": true,
	},
	WeaponID.SHOTGUN: {
		"id": WeaponID.SHOTGUN,
		"name": "Shotgun",
		"damage": 6,
		"fire_rate": 0.60,
		"ammo": 50,
		"bullet_speed": 700.0,
		"spread": 25.0,
		"bullets_per_shot": 5,
		"bullet_scale": 0.7,
		"color": Color(1.0, 0.5, 0.3),
		"auto": false,
	},
	WeaponID.ROCKET: {
		"id": WeaponID.ROCKET,
		"name": "Rocket",
		"damage": 50,
		"fire_rate": 0.80,
		"ammo": 30,
		"bullet_speed": 500.0,
		"spread": 0.0,
		"bullets_per_shot": 1,
		"bullet_scale": 1.5,
		"color": Color(0.9, 0.3, 0.1),
		"auto": false,
	},
	WeaponID.FLAMETHROWER: {
		"id": WeaponID.FLAMETHROWER,
		"name": "Flamethrower",
		"damage": 4,
		"fire_rate": 0.05,
		"ammo": 150,
		"bullet_speed": 400.0,
		"spread": 15.0,
		"bullets_per_shot": 1,
		"bullet_scale": 1.0,
		"color": Color(1.0, 0.4, 0.1),
		"auto": true,
	},
}

# ============================================================
# Helpers
# ============================================================

static func get_weapon(weapon_id: int) -> Dictionary:
	return WEAPONS.get(weapon_id, WEAPONS[WeaponID.PISTOL])

static func get_name(weapon_id: int) -> String:
	return get_weapon(weapon_id)["name"]

static func get_damage(weapon_id: int) -> int:
	return get_weapon(weapon_id)["damage"]

static func get_fire_rate(weapon_id: int) -> float:
	return get_weapon(weapon_id)["fire_rate"]

static func get_bullet_speed(weapon_id: int) -> float:
	return get_weapon(weapon_id)["bullet_speed"]

static func get_spread(weapon_id: int) -> float:
	return get_weapon(weapon_id)["spread"]

static func get_bullets_per_shot(weapon_id: int) -> int:
	return get_weapon(weapon_id)["bullets_per_shot"]

static func get_bullet_scale(weapon_id: int) -> float:
	return get_weapon(weapon_id)["bullet_scale"]

static func get_color(weapon_id: int) -> Color:
	return get_weapon(weapon_id)["color"]

static func is_auto(weapon_id: int) -> bool:
	return get_weapon(weapon_id)["auto"]

static func get_all_ids() -> Array:
	return WEAPONS.keys()
