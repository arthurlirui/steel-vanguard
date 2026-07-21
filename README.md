# Steel Vanguard (钢铁先锋)

A Metal Slug-style side-scrolling run-and-gun shooter built with Godot 4.3 for mobile.

## Features

- **Side-scrolling run-and-gun** action in the spirit of Metal Slug
- **Multi-weapon system**: Pistol (infinite), Heavy Machine Gun (H), Shotgun (S), Rocket Launcher (R), Flamethrower (F)
- **Vehicle system**: SV-001-style tank with Vulcan cannon + main cannon, enter/exit with i-frames
- **Enemy AI state machine**: Patrol → Spot → Chase → Attack → Hit → Dead
- **Parallax scrolling** background (3–4 layers for depth)
- **POW rescue system** — free hostages for bonus score
- **BOSS battles**
- **Destructible scene elements**
- **Mobile touch controls** — virtual joystick + action buttons
- **Grenade sub-weapon** with limited supply
- **Melee attack** (knife when close to enemies)
- **Portrait 1080×1920** orientation for mobile

## Tech

- Godot 4.3 (GL Compatibility renderer)
- GDScript
- No external art assets — uses ColorRect / primitive shapes as placeholders

## Getting Started

1. Open the project folder in Godot 4.3+
2. Press **F5** to run
3. On desktop: use keyboard (arrow keys + Z/X/C/V/B) or connect a touch device
4. On mobile: on-screen virtual joystick + buttons appear automatically

## Controls

| Action          | Keyboard     | Touch            |
|-----------------|--------------|------------------|
| Move Left/Right | ← / →        | Virtual joystick |
| Jump            | Z / Space    | Jump button      |
| Shoot           | X            | Shoot button     |
| Grenade         | C            | Grenade button   |
| Enter Vehicle   | V            | Vehicle button   |
| Switch Weapon   | B / 1-5      | Weapon button    |
| Crouch          | ↓            | Joystick down    |

## License

MIT
