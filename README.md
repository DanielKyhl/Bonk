# Momentum (working title)

A survivor game with Megabonk-style movement, built in Godot 4. You play the Crusader and carve through hordes of the undead while your weapons fire on their own. Movement is how you survive: bunny hop, slide down hills, slam and launch off ramps to outrun the horde.

- `game/`: the Godot 4.7 project (the actual game)
- `prototype/`: the original browser movement prototype (open `prototype/index.html`)

## Play it

**From a release:** download the zip for your system from the repo's Releases page, unzip and run it.
- Windows: run `Momentum.exe`. If Windows says it protected your PC, click *More info*, then *Run anyway* (the game isn't code-signed).
- macOS: right-click `Momentum.app` and choose *Open* the first time.

**From source:** install [Godot 4.7](https://godotengine.org/download), open `game/project.godot` and press F5.

## Controls

| Keyboard | Gamepad | Action |
| --- | --- | --- |
| WASD / arrows | Left stick | Run |
| Space | A | Jump. Press again right as you land to bunny hop (+10% speed per hop) |
| Shift / C | B / RB / RT | Slide; in the air it's a slam |
| 1, 2, 3 | D-pad + A | Pick a level-up card |
| Esc | Start | Pause |
| F |  | Toggle the debug line (FPS, enemies, speed) |
| F9 |  | Lower the 3D render resolution (100% / 85% / 70%) if the game stutters |
| F11 |  | Fullscreen |

## Tricks

- **Bunny hop**: jump the moment you land for +10% speed. Hold jump to auto-hop without the boost.
- **Slide**: slides speed up downhill. Steep ground turns to dirt and rock.
- **Slam**: slide in the air to drop fast, then slide out of the landing.
- **Stomp**: land on a skeleton's head to bounce off it.
- **Landings**: landing on a downslope turns your fall into speed.
- **Ramps, crests and holy springs** launch you. Jump right as you leave a ramp for a much bigger launch.
- **Crusader**: Holy Aegis blocks one hit, then recharges for 12 seconds.

Movement never deals damage by itself; your weapons do the killing.

## Making a release

Push a tag and GitHub Actions builds Windows, Linux and macOS and publishes them as a release:

```sh
git tag v0.1.0
git push origin v0.1.0
```

The *Build game* workflow can also be run by hand from the Actions tab; the zips then show up as run artifacts instead of a release.

## Project layout (game/)

| Path | What's there |
| --- | --- |
| `scripts/data/defs.gd` | Heroes, weapons, tomes and balance numbers |
| `scripts/player/player.gd` | Movement physics (tuning constants at the top) |
| `scripts/world/` | Map definitions, terrain, props, grass |
| `scripts/enemies/` | Enemy manager and baked vertex-animation data |
| `scripts/combat/` | Weapons and pickups |
| `scripts/run/` | Run controller, run state, spawn director |
| `scripts/ui/` | HUD and menus |
| `tools/bake_vat.gd` | Bakes enemy animations into textures (re-run after changing enemy models) |
| `tests/` | Headless movement tests: `godot --headless --path game res://tests/movement_test.tscn` |

## Credits

- 3D models: [KayKit](https://kaylousberg.com) by Kay Lousberg, CC0 (licenses in `game/assets/kaykit/*/LICENSE.txt`)
- Fonts: Cinzel and Barlow Condensed, SIL Open Font License (`game/assets/fonts/*-OFL.txt`)
