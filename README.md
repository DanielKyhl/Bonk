# Momentum (working title)

A dark-fantasy pixel-art survivor game with Megabonk-style movement, built in Godot 4. Pick one of ten heroes and carve through hordes of the undead while your weapons fire on their own. Movement is how you survive: bunny hop, slide down steep hills and slam to outrun the horde.

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
| WASD / arrows | Left stick | Run (relative to the camera: W is always up the screen) |
| Mouse | Right stick | Turn the camera around the hero |
| Space | A | Jump. Press again right as you land to bunny hop (+10% speed per hop) |
| Shift / C | B / RB / RT | Slide; in the air it's a slam |
| E | X | Open a chest (or use a shrine) |
| 1, 2, 3 | D-pad + A | Pick a level-up card |
| Esc | Start | Pause (frees the mouse; click the game to capture it again) |
| F |  | Toggle the debug line (FPS, enemies, speed) |
| F11 |  | Fullscreen |

## A run

Pick a hero and a map in the main menu (heroes unlock by reaching goals shown on their locked cards; maps unlock by beating the previous map's boss).

- A stage lasts 10 minutes; the horde grows and toughens, elites come every minute, and at 10:00 the endless final swarm begins.
- Explore for **chests** (gold, pricier each time; elites drop free golden ones) and **shrines**: stand in a prayer circle for a blessing, wake a cursed altar for elites and golden chests, or make an offering to greed.
- Somewhere a tall beam marks **the boss altar**. You can summon the boss any time, but it takes a strong build to beat. Slay it and the altar becomes a portal: step through to carry your whole build on to the next map (a tougher stage) and unlock that map in the menu, or stay and fight on (kills score double).

## Maps

1. **Hallowed Vale**: a dying valley at dusk. Skeletons, ghouls, skeleton warriors and mages; boss Varnoth, the Lich King.
2. **Frostfang Peaks**: frozen mountains with the longest slides. Draugr, ice wraiths, draugr warriors and frost mages; boss Skarn, the Draugr King.
3. **Blightmire**: a rotting swamp of bogs and stumps. Bog zombies, sackheads, bog brutes and plague witches; boss Mother Rot, the Bog Witch.

## Heroes

The Crusader is ready from the start; each other hero unlocks by a goal shown on its locked card. Every hero starts with a signature weapon, and once a hero is unlocked that weapon can turn up in any hero's level-ups.

| Hero | Signature weapon | Passive | Unlock |
| --- | --- | --- | --- |
| Aurelia, the Crusader | Radiant Flail: sweeps around you | Holy Aegis blocks one hit, then recharges for 12 s | Start |
| Kaerr, the Dragonborn | Dragon Breath: a cone of fire | Take 15% less damage | Slay a map's boss |
| Ysolde, the Stormcaller | Chain Lightning: leaps foe to foe | +15% attack speed | Reach level 30 in one run |
| Vargr, the Werewolf | Rending Claws: fast rakes in front | Heal 3% of damage dealt | Slay 1,500 foes in one run |
| Harrow, the Chainwarden | Warden's Chains: a long lash, side to side | Attackers take 25 damage | Open 12 chests in one run |
| Elsin, the Frost Witch | Frost Shards: a piercing fan that slows | Hits have a 30% chance to chill | Survive 3 minutes of the final swarm |
| Oszric, the Rune Golem | Rune Slam: crushes and hurls back all around | Take 10% less damage, +20% area | Pray at 6 shrines in one run |
| Morvane, the Wraith Knight | Soul Blade: flies out and returns | Rise once from death | Slay 100 elites in all |
| Othric, the Necromancer | Soul Skulls: homing skulls that burst | +15% XP, +20% pickup range | Slay 25,000 foes in all |
| Tessaly, the Chronomancer | Time Rift: a zone that slows and grinds | +10% attack speed, hits may slow | Slay a boss before 8:00 |

Chilled or slowed enemies turn frost-blue and move at half speed.

## Tricks

- **Bunny hop**: jump the moment you land for +10% speed. Hold jump to auto-hop without the boost.
- **Slide**: slides speed up downhill. Steep ground turns to dirt and rock.
- **Slam**: slide in the air to drop fast, then slide out of the landing.
- **Stomp**: land on a skeleton's head to bounce off it.
- **Landings**: landing on a downslope turns your fall into speed.
- **Steep hills** are where speed comes from: slide down them. The Tor, Windmill Ridge, the barrow mounds and the curved map edges are the big ones.
- **Kickers** (grassy rises with a sharp lip) and **holy springs** launch you. Jump right as you leave a lip for a bigger launch.
- **Cliffs** can't be climbed: find the natural slope up (the Keep's is on its north side).

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
| `scripts/enemies/` | Enemy manager (flat arrays, drawn as sprite MultiMeshes) |
| `scripts/combat/` | Weapons and pickups |
| `scripts/run/` | Run controller, run state, spawn director |
| `scripts/ui/` | Main menu, HUD, in-run menus and minimap |
| `scripts/render/` | Pixel view (low-res render and upscale), sprite atlases and batches |
| `tools/map_preview.gd` | Renders a top-down hillshade of a map (`godot --headless --path game --script res://tools/map_preview.gd -- out.png`) |
| `tests/` | Headless movement tests on their own test map: `godot --headless --path game res://tests/movement_test.tscn` |

## Rebuilding the art and sound

The pixel art is generated by scripts in `tools/sprites/` (Python 3 with Pillow):

- `build.py <LPC generator checkout>`: composites the LPC layers into character atlases and writes the credits
- `icons.py <game-icons checkout>`: weapon, tome and item icons
- `pickups.py`, `weapons_fx.py`, `ui_frames.py`: pickups, weapon effects and UI frames

The sound is synthesized too, by `tools/audio/` (Python 3 with numpy, scipy and soundfile):

- `sfx.py`: every sound effect (`game/assets/audio/sfx/`)
- `music.py [track ...]`: the looping music: `menu`, `vale`, `frost`, `bog` and `boss` (`game/assets/audio/music/`)
- `dsp.py`: the small synth toolkit both use (oscillators, filters, bells, choir, plucked strings, drums, reverb)

## Credits

- Character sprites: [Universal LPC Spritesheet Character Generator](https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator) contributors, OGA-BY / CC-BY-SA / GPL (per-sheet authors and licenses in `game/assets/sprites/CREDITS.txt`)
- Icons: based on [game-icons.net](https://game-icons.net) by Lorc, Delapouite, sbed and others, CC BY 3.0 (`game/assets/icons/CREDITS.txt`)
- 3D props: [KayKit](https://kaylousberg.com) by Kay Lousberg, CC0 (licenses in `game/assets/kaykit/*/LICENSE.txt`)
- Sound effects and music: original, synthesized by `tools/audio/`
- Fonts: Jacquard 24, Jersey 10 and Pixelify Sans, SIL Open Font License (`game/assets/fonts/*-OFL.txt`)
