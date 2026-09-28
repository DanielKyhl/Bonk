# Momentum Lab

A top-down survivors-style prototype that tests one question: can the movement tricks that make games like Megabonk fun survive in 2D, where the game is much cheaper to run?

The map isn't flat. It's a heightfield with hills, bowls and ramps, and the player has real vertical physics: gravity, slopes, launches and landings. It's drawn top-down in 2D, with a shadow and a dashed altitude line to show how high you are.

## Run it

Open `prototype/index.html` in a browser. There's no build step and there are no dependencies.

If your browser won't load the script from a local file, serve the folder instead:

```sh
cd prototype && python3 -m http.server 8000
# then open http://localhost:8000
```

## Controls

| Input | Action |
| --- | --- |
| WASD / arrows | Run |
| Space | Jump |
| Shift (or C) | Slide on the ground, slam in the air |
| 1, 2, 3 | Pick an upgrade |
| Esc | Pause |
| H / F | Hide the trick list / toggle the FPS counter |

On touch screens: drag anywhere on the left side to steer, and use the Jump and Slide buttons on the right.

## Tricks

- **Bunny hop**: press jump right as you land for +12% speed per hop, up to 123 km/h. Hold jump to auto-hop: you keep your speed but get no boost.
- **Slide**: slides speed up downhill and slowly lose speed on flat ground. Tightly packed contour lines mean steep ground.
- **Slam**: Shift in the air. You get a shockwave on impact, then slide out with extra speed.
- **Stomp**: land on an enemy to bounce off it. It counts as a perfect hop.
- **Landings**: landing on a downslope turns your fall into ground speed. Landing on an upslope costs you speed.
- **Ramps and crests**: run off a ramp lip or a hill crest fast to catch air. Jump right as you leave the ground for a much bigger launch.
- **Pads**: yellow rings launch you straight up.

Speed feeds damage. Your bolts hit harder the faster you move, slides tackle enemies out of the way, and half the upgrades lean into it.

## Tuning

Every movement number lives in `CFG` at the top of `prototype/game.js`. You can also change them live from the browser console through `__lab`, for example `__lab.CFG.gravity = 1800`.

## Why it runs cheaply

- Plain Canvas 2D with no engine and no libraries.
- The terrain is painted once to an offscreen canvas, so each frame draws it as a single image.
- Enemies are pre-rendered sprites, and collisions go through a spatial grid rebuilt each frame.
- In headless Chromium with software rendering, 600 enemies run at 60 fps.
