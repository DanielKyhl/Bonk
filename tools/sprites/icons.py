"""Builds the pixel icons for weapons, tomes and items from game-icons.net SVGs.

    python3 tools/sprites/icons.py /path/to/game-icons/icons

Each silhouette is rasterized large (via Godot's SVG loader), shrunk to a
24px mask by coverage, then shaded like hand-made pixel art: a base color,
a lit top-left edge, a shaded bottom-right edge and a 1px dark outline.
Writes game/assets/icons/<id>.png and game/assets/icons/CREDITS.txt.
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "icons")
GODOT = os.environ.get("GODOT", "/home/user/tools/godot")
SIZE = 24
SS = 8  # supersampling per pixel

## id -> (svg, base color)
ICONS = {
    # Weapons
    "radiant_flail": ("delapouite/flail.svg", (236, 196, 96)),
    "holy_javelin": ("delapouite/sun-spear.svg", (240, 226, 170)),
    "sacred_orbs": ("lorc/orbital.svg", (150, 206, 240)),
    "smite": ("lorc/sunbeams.svg", (250, 232, 170)),
    "consecration": ("lorc/beams-aura.svg", (240, 190, 90)),
    "throwing_axes": ("lorc/battered-axe.svg", (200, 204, 214)),
    # Hero signature weapons
    "dragon_breath": ("lorc/dragon-breath.svg", (240, 120, 50)),
    "chain_lightning": ("willdabeast/chain-lightning.svg", (150, 200, 250)),
    "rending_claws": ("lorc/claw-slashes.svg", (220, 70, 70)),
    "warden_chains": ("lorc/crossed-chains.svg", (176, 180, 192)),
    "frost_shards": ("lorc/ice-spear.svg", (150, 214, 250)),
    "rune_slam": ("lorc/earth-crack.svg", (220, 150, 80)),
    "soul_blade": ("lorc/relic-blade.svg", (120, 230, 210)),
    "soul_skulls": ("lorc/skull-bolt.svg", (190, 160, 240)),
    "time_rift": ("lorc/time-trap.svg", (190, 130, 240)),
    # Tomes
    "might": ("lorc/mailed-fist.svg", (222, 92, 72)),
    "haste": ("lorc/hourglass.svg", (236, 196, 96)),
    "reach": ("delapouite/expand.svg", (186, 140, 230)),
    "swiftness": ("lorc/winged-leg.svg", (150, 206, 240)),
    "leaping": ("delapouite/jump-across.svg", (140, 214, 150)),
    "iron": ("delapouite/templar-shield.svg", (190, 196, 210)),
    "vitality": ("lorc/glass-heart.svg", (226, 72, 84)),
    "renewal": ("sbed/regeneration.svg", (120, 214, 130)),
    "attraction": ("lorc/magnet.svg", (220, 90, 80)),
    "wisdom": ("lorc/book-aura.svg", (110, 190, 236)),
    "precision": ("delapouite/crosshair.svg", (240, 150, 70)),
    "multitude": ("lorc/thrown-daggers.svg", (200, 204, 214)),
    "bhop": ("lorc/sprint.svg", (150, 206, 240)),
    # Items
    "iron_ration": ("lorc/meat.svg", (190, 96, 80)),
    "whetstone": ("lorc/sword-smithing.svg", (190, 196, 210)),
    "pilgrim_boots": ("lorc/boots.svg", (160, 116, 76)),
    "sand_glass": ("lorc/sundial.svg", (226, 196, 120)),
    "lodestone": ("lorc/magnet-blast.svg", (200, 90, 90)),
    "horseshoe": ("delapouite/horseshoe.svg", (170, 170, 180)),
    "bone_charm": ("lorc/charm.svg", (226, 214, 180)),
    "tithe_purse": ("delapouite/coins.svg", (240, 200, 90)),
    "tabard": ("delapouite/cape-armor.svg", (200, 60, 60)),
    "war_horn": ("lorc/bugle-call.svg", (220, 180, 110)),
    "holy_water": ("delapouite/holy-water.svg", (120, 190, 240)),
    "spiked_pauldron": ("delapouite/spiked-shoulder-armor.svg", (170, 176, 190)),
    "angel_feather": ("lorc/feather.svg", (236, 236, 250)),
    "heart_jar": ("lorc/heart-bottle.svg", (220, 70, 90)),
    "cleric_beads": ("delapouite/prayer-beads.svg", (200, 170, 120)),
    "vampire_fang": ("skoll/fangs.svg", (230, 230, 220)),
    "crown_thorns": ("lorc/crown-of-thorns.svg", (160, 130, 90)),
    "saints_finger": ("delapouite/hand-of-god.svg", (250, 226, 160)),
    "reaper_sigil": ("lorc/scythe.svg", (170, 150, 200)),
    "endless_quiver": ("delapouite/quiver.svg", (180, 140, 90)),
    "phoenix_ash": ("lorc/burning-embers.svg", (250, 140, 60)),
    "holy_grail": ("lorc/holy-grail.svg", (250, 210, 100)),
    "dawn_blade": ("lorc/broadsword.svg", (250, 220, 140)),
}

OUTLINE = (14, 10, 16, 255)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def pixelate(big):
    """Coverage-based downsample of the white icon to a SIZE x SIZE mask."""
    px = big.convert("L").load()
    mask = [[False] * SIZE for _ in range(SIZE)]
    for y in range(SIZE):
        for x in range(SIZE):
            s = 0
            for yy in range(SS):
                for xx in range(SS):
                    s += px[x * SS + xx, y * SS + yy]
            mask[y][x] = s / (SS * SS * 255.0) > 0.42
    return mask


def paint(mask, color):
    """Base fill with lit/shaded edges and a dark outline, 1px padding."""
    n = SIZE + 2
    img = Image.new("RGBA", (n, n))
    px = img.load()

    def on(x, y):
        return 0 <= x < SIZE and 0 <= y < SIZE and mask[y][x]

    hi = shade(color, 1.25)
    lo = shade(color, 0.62)
    for y in range(SIZE):
        for x in range(SIZE):
            if not on(x, y):
                continue
            c = color
            if not on(x - 1, y) or not on(x, y - 1):
                c = hi
            elif not on(x + 1, y) or not on(x, y + 1):
                c = lo
            px[x + 1, y + 1] = c + (255,)
    for y in range(n):
        for x in range(n):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if on(x - 1 + dx, y - 1 + dy):
                    px[x, y] = OUTLINE
                    break
    return img


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "/home/user/pixel/icons"
    os.makedirs(OUT, exist_ok=True)
    tmp = tempfile.mkdtemp()
    args = [GODOT, "--headless", "--script", os.path.join(os.path.dirname(__file__), "raster_svg.gd"), "--", str(SIZE * SS)]
    for iid, (svg, _) in ICONS.items():
        args += [os.path.join(src, svg), os.path.join(tmp, iid + ".png")]
    subprocess.run(args, check=True, capture_output=True)
    authors = {}
    for iid, (svg, color) in ICONS.items():
        big = Image.open(os.path.join(tmp, iid + ".png"))
        # game-icons draw a white glyph on a black square.
        paint(pixelate(big), color).save(os.path.join(OUT, iid + ".png"))
        authors.setdefault(svg.split("/")[0], []).append(svg)
    lines = ["Icons are based on game-icons.net (https://game-icons.net), licensed CC BY 3.0,", "redrawn as pixel icons. Authors and source icons:", ""]
    for a, files in sorted(authors.items()):
        lines.append("%s: %s" % (a, ", ".join(sorted(f.split("/")[1] for f in files))))
    with open(os.path.join(OUT, "CREDITS.txt"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print("icons:", len(ICONS))


if __name__ == "__main__":
    main()
