# Steel Vanguard — Design Document

## Overview

Steel Vanguard (钢铁先锋) is a Metal Slug-inspired side-scrolling run-and-gun shooter designed for mobile (portrait 1080×1920). Built with Godot 4.3 using the GL Compatibility renderer for broad device support.

## Core Pillars

1. **Run & Gun** — Constant forward momentum; the player pushes through waves of enemies.
2. **Weapon Variety** — Switch between 5 distinct weapons on the fly.
3. **Vehicle Power** — Enter the Slug Tank for heavy firepower and armor.
4. **Tight Controls** — Responsive movement with mobile-first touch design.
5. **Spectacle** — Explosions, screen shake, parallax backgrounds, prisoner rescues.

## Game States

```
MENU → PLAYING → PAUSED → GAME_OVER → VICTORY
```

Managed by `GameManager` autoload singleton.

## Player Design

### States
IDLE → RUN → JUMP → FALL → CROUCH → SHOOT → KNIFE → GRENADE → HURT → DIE → VEHICLE

### Movement
- Left/right walk with acceleration/friction
- Variable-height jump
- Crouch to dodge bullets and shoot low
- Shooting stops horizontal movement (classic Metal Slug feel)

### Combat
- **8-direction aiming**: up, down, left, right, 4 diagonals
- **Melee**: automatic knife when enemy is within range and not shooting
- **Grenade**: arc throw, limited supply (start with 10)
- **I-frames**: 1.5s invincibility after taking a hit, blinking sprite

### Weapons

| ID | Name           | Damage | Fire Rate (s) | Ammo  | Spread | Bullet Speed |
|----|----------------|--------|---------------|-------|--------|-------------|
| 0  | Pistol         | 10     | 0.35          | ∞     | 0°     | 800         |
| 1  | Heavy MG (H)   | 8      | 0.08          | 200   | 5°     | 1000        |
| 2  | Shotgun (S)    | 6×5    | 0.60          | 50    | 25°    | 700         |
| 3  | Rocket (R)     | 50     | 0.80          | 30    | 0°     | 500         |
| 4  | Flamethrower(F)| 4      | 0.05          | 150   | 15°    | 400         |

- Pick up weapon crates to switch/replenish.
- Running out of ammo reverts to Pistol.

## Vehicle — SV-001 Style Tank

- **Vulcan cannon**: rapid fire, 360° aim
- **Main cannon**: heavy damage, slow fire rate, screen shake
- **Armor**: absorbs hits; tank takes damage instead of player
- **Enter/Exit**: press V near tank; 2s i-frames on exit
- **Movement**: slower than on-foot, cannot jump

## Enemy AI

### States
PATROL → SPOT → CHASE → ATTACK → HIT → DEAD

### Types
- **Soldier**: basic infantry, patrols, shoots on sight
- **Shield Soldier**: blocks frontal bullets, vulnerable from behind
- **Bazooka Soldier**: fires slow rockets, keeps distance
- **BOSS**: multi-phase, heavy attacks, large health pool

## Level Design

- Linear side-scrolling with parallax backgrounds (3-4 layers)
- Destructible crates and barrels
- POW prisoners to rescue for score bonuses
- Weapon crate pickups
- Tank drop zones
- End-of-level BOSS encounter

## Mobile Controls

- **Left side**: virtual joystick (move + aim direction)
- **Right side**: buttons for Jump, Shoot, Grenade, Vehicle, Weapon Switch
- Auto-detect touch; hide on desktop

## Visual Style

- Placeholder art using ColorRect and primitive shapes
- Each entity has a distinct color:
  - Player: blue (#4488ff)
  - Enemy soldier: red (#ff4444)
  - Tank: green (#44aa44)
  - Bullets: yellow (#ffdd44)
  - Explosions: orange-red gradient

## Audio (Placeholder)

- Shoot, explosion, jump, hit, death, pickup, grenade
- Background music per level
- BOSS music
