# Audio

Place audio assets here. The project ships with **no audio files** — the
`AudioManager` autoload defines the SFX/BGM API and trigger points, but every
stream slot is `null` and `play_sfx()`/`play_bgm()` are silent no-ops until
assets are added.

## How to wire assets

1. Drop the files under this folder (`assets/audio/`).
2. Open `scripts/audio_manager.gd` and, in `_build_stream_table()`, replace the
   `null` placeholder for each key with `load("res://assets/audio/<file>")`.
3. The existing `AudioManager.play_sfx(...)` calls throughout the codebase
   start playing automatically — no other wiring needed.

## SFX keys → expected files

The `StringName` keys are defined as `const` in `audio_manager.gd` and used by
all gameplay scripts. Keep filenames in sync with this table.

| SFX key constant            | Key (StringName)        | Suggested file                  | Trigger point |
|-----------------------------|-------------------------|---------------------------------|---------------|
| `SFX_PLAYER_SHOOT`          | `player_shoot`          | `sfx/player_shoot.wav`          | Player fires any weapon |
| `SFX_PLAYER_GRENADE`        | `player_grenade`        | `sfx/player_grenade.wav`        | Player throws a grenade |
| `SFX_PLAYER_MELEE`          | `player_melee`          | `sfx/player_melee.wav`          | Player knife hits |
| `SFX_PLAYER_JUMP`           | `player_jump`           | `sfx/player_jump.wav`           | Player jumps |
| `SFX_PLAYER_HURT`           | `player_hurt`           | `sfx/player_hurt.wav`           | Player takes damage |
| `SFX_PLAYER_DIE`            | `player_die`            | `sfx/player_die.wav`            | Player dies |
| `SFX_PLAYER_VEHICLE_IN`     | `player_vehicle_in`     | `sfx/player_vehicle_in.wav`     | Player enters tank |
| `SFX_PLAYER_VEHICLE_OUT`    | `player_vehicle_out`    | `sfx/player_vehicle_out.wav`    | Player exits tank |
| `SFX_ENEMY_SHOOT`           | `enemy_shoot`           | `sfx/enemy_shoot.wav`           | Any enemy fires |
| `SFX_ENEMY_HURT`            | `enemy_hurt`            | `sfx/enemy_hurt.wav`            | Enemy takes damage |
| `SFX_ENEMY_DIE`             | `enemy_die`             | `sfx/enemy_die.wav`             | Enemy dies |
| `SFX_ENEMY_HOP`             | `enemy_hop`             | `sfx/enemy_hop.wav`             | BUG variant leaps (distinct from shooting) |
| `SFX_TANK_CANNON`           | `tank_cannon`           | `sfx/tank_cannon.wav`           | Tank main cannon fires |
| `SFX_TANK_HIT`              | `tank_hit`              | `sfx/tank_hit.wav`              | Tank takes damage |
| `SFX_TANK_EXPLODE`          | `tank_explode`          | `sfx/tank_explode.wav`          | Tank destroyed |
| `SFX_EXPLOSION`             | `explosion`             | `sfx/explosion.wav`             | Generic explosion (grenade, destructible) |
| `SFX_PICKUP`                | `pickup`                | `sfx/pickup.wav`                | Player collects a pickup |
| `SFX_POW_RESCUE`            | `pow_rescue`            | `sfx/pow_rescue.wav`            | POW rescued |
| `SFX_UI_CLICK`              | `ui_click`              | `sfx/ui_click.wav`              | HUD button click |
| `SFX_PAUSE`                 | `pause`                 | `sfx/pause.wav`                 | Pause toggled on |
| `SFX_GAME_OVER`             | `game_over`             | `sfx/game_over.wav`             | Game over state entered |
| `SFX_VICTORY`               | `victory`               | `sfx/victory.wav`               | Victory state entered |

## Music (BGM)

BGM tracks are keyed by `StringName` in `audio_manager.gd::_bgm_streams`. No
slots are populated yet.

| Suggested key | Suggested file        | When |
|---------------|-----------------------|------|
| `bgm_level`   | `bgm/bgm_level.ogg`   | Level gameplay (call `AudioManager.play_bgm(&"bgm_level")` from `level.gd`) |
| `bgm_boss`    | `bgm/bgm_boss.ogg`    | Boss encounter (call when `_spawn_boss()` runs) |
| `bgm_menu`    | `bgm/bgm_menu.ogg`    | Main menu (no menu scene yet — pending) |

## Format guidelines

- SFX: `.wav`, 22 kHz, mono, short (0.1–0.8s).
- BGM: `.ogg`, loopable.
- Keep total SFX memory modest — the SFX pool has 6 voices (concurrent limit).
